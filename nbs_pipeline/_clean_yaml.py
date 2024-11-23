import os
import shutil
from dvats.utils import print_flush

def copy_and_verify_yaml(wdb_user, wdb_project, example, verbose=0):
    """
    Copies files from a specific example directory to the base configuration path
    and verifies/modifies `.yaml` files in the destination.

    Parameters:
        wdb_user (str): The desired value for the `user` field in the `.yaml` files.
        wdb_project (str): The desired value for the `project_name` field in the `.yaml` files.
        example (str): The name of the example directory containing files to be copied.
        verbose (int): Controls the verbosity of the output (0 = none, 1 = main flow, 2 = detailed, 3 = debug).

    Returns:
        None
    """
    # Define the base paths
    cpath = os.path.expanduser('~/work/nbs_pipeline/config')
    examples_path = os.path.join(cpath, 'examples', example)

    # Verify the example path exists
    if not os.path.exists(examples_path):
        if verbose > 0:
            print_flush(f"Example path does not exist: {examples_path}")
        return

    # Copy files to the base configuration path
    for file_name in os.listdir(examples_path):
        src_file = os.path.join(examples_path, file_name)
        dst_file = os.path.join(cpath, file_name)

        if os.path.isfile(src_file):
            shutil.copy2(src_file, dst_file)
            if verbose > 1:
                print_flush(f"Copied: {src_file} -> {dst_file}")

            # If the copied file is a YAML file, process it in the destination
            if file_name.endswith('.yaml'):
                if verbose > 0:
                    print_flush(f"Processing YAML file: {dst_file}")

                # Replace `user` and `project_name` lines directly in place in the destination
                search_and_replace_line_in_file(
                    dst_file, 
                    "user: &wdb_user", 
                    f"user: &wdb_user {wdb_user}", 
                    verbose
                )
                search_and_replace_line_in_file(
                    dst_file, 
                    "project_name: &wdb_project", 
                    f"project_name: &wdb_project {wdb_project}", 
                    verbose
                )


def clean_all_examples(wdb_user, wdb_project, verbose=0):
    """
    Cleans all YAML files in the `examples` folder by verifying and modifying their contents in place.

    Parameters:
        wdb_user (str): The desired value for the `user` field in the `.yaml` files.
        wdb_project (str): The desired value for the `project_name` field in the `.yaml` files.
        verbose (int): Controls the verbosity of the output (0 = none, 1 = main flow, 2 = detailed, 3 = debug).

    Returns:
        None
    """
    # Define the base path for examples
    examples_path = os.path.expanduser('~/work/nbs_pipeline/config/examples')
    
    # Check if the examples path exists
    if not os.path.exists(examples_path):
        if verbose > 0:
            print_flush(f"Examples path does not exist: {examples_path}")
        return

    # Traverse all subdirectories in `examples`
    for example in os.listdir(examples_path):
        example_path = os.path.join(examples_path, example)
        if os.path.isdir(example_path):
            if verbose > 0:
                print_flush(f"Processing example: {example}")

            # Process all YAML files in the current example subdirectory
            for file_name in os.listdir(example_path):
                if file_name.endswith('.yaml'):
                    yaml_path = os.path.join(example_path, file_name)
                    if verbose > 0:
                        print_flush(f"Processing YAML file: {yaml_path}")

                    # Replace `user` and `project_name` lines directly in place
                    search_and_replace_line_in_file(
                        yaml_path, 
                        "user: &wdb_user", 
                        f"user: &wdb_user {wdb_user}", 
                        verbose
                    )
                    search_and_replace_line_in_file(
                        yaml_path, 
                        "project_name: &wdb_project", 
                        f"project_name: &wdb_project {wdb_project}", 
                        verbose
                    )


def search_and_replace_line_in_file(file_path, search_key, replacement_value, verbose=0):
    """
    Replaces the value after ':' for a specific key in the file, preserving indentation.

    Parameters:
        file_path (str): The path to the file to be modified.
        search_key (str): The key to search for at the start of a line.
        replacement_value (str): The new value to replace the existing value after ':'.
        verbose (int): Controls the verbosity of the output (0 = none, 1 = main flow, 2 = detailed, 3 = debug).

    Returns:
        bool: True if modifications were made, False otherwise.
    """
    modified = False
    with open(file_path, 'r') as file:
        lines = file.readlines()

    with open(file_path, 'w') as file:
        for line in lines:
            if line.strip().startswith(search_key):
                # Preserve the indentation and replace only the value after ':'
                parts = line.split(":", 1)
                if len(parts) > 1:
                    indentation = parts[0]
                    new_line = f"{indentation}: {replacement_value}\n"
                    if verbose > 1:
                        print_flush(f"Replacing line: {line.strip()} -> {new_line.strip()} in {file_path}")
                    file.write(new_line)
                    modified = True
                    continue
            file.write(line)

    if not modified and verbose > 2:
        print_flush(f"No match for key '{search_key}' in {file_path}")
    return modified