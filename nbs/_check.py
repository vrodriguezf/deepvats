import os
import nbformat
from nbconvert import PythonExporter
import argparse
import subprocess

def convert_and_check(notebook_path, context_lines):
    # 1. Leer el notebook
    with open(notebook_path, 'r', encoding='utf-8') as f:
        nb = nbformat.read(f, as_version=4)

    # 2. Convertir a script Python
    exporter = PythonExporter()
    script, _ = exporter.from_notebook_node(nb)
    
    temp_script_path = notebook_path.replace('.ipynb', '_temp.py')
    
    with open(temp_script_path, 'w', encoding='utf-8') as f:
        f.write(script)
    
    print(f"[INFO] Converted notebook saved as: {temp_script_path}")
    
    # 3. Verificar errores de sintaxis
    try:
        result = subprocess.run(
            ['python', '-m', 'py_compile', temp_script_path],
            capture_output=True, text=True
        )
        if result.returncode == 0:
            print("[SUCCESS] No syntax errors found.")
        else:
            print("[ERROR] Syntax errors detected:\n")
            print(result.stderr)
            
            # Extraer línea del error desde el script
            with open(temp_script_path, 'r', encoding='utf-8') as f:
                lines = f.readlines()
            
            # Obtener número de línea desde el mensaje de error
            for line in result.stderr.split('\n'):
                if 'File' in line and 'line' in line:
                    parts = line.split(',')
                    line_number = int(parts[1].split()[-1])  # Extrae el número de línea
                    
                    start = max(0, line_number - context_lines - 1)
                    end = min(len(lines), line_number + context_lines)

                    print(f"\n[ERROR] Context around line {line_number}:\n")
                    for i in range(start, end):
                        prefix = '>> ' if i == line_number - 1 else '   '
                        print(f"{prefix}{i + 1:4}: {lines[i]}", end='')

                    break
                
    except Exception as e:
        print(f"[ERROR] Failed to compile: {e}")
    
    # 4. Eliminar el archivo temporal
    os.remove(temp_script_path)
    print(f"[INFO] Temporary file removed: {temp_script_path}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Check syntax errors in .ipynb files.")
    parser.add_argument("notebook", help="Path to the Jupyter notebook (.ipynb) file.")
    parser.add_argument("--context", type=int, default=1, help="Number of lines to print before and after the error.")
    args = parser.parse_args()

    convert_and_check(args.notebook, args.context)
