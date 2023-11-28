import subprocess

def get_gpu_memory(device):
    total_memory = subprocess.check_output(["nvidia-smi", "--query-gpu=memory.total", "--format=csv,noheader,nounits", "--id=" + str(device)])
    total_memory = int(total_memory.decode().split('\n')[0])
    used_memory = subprocess.check_output(["nvidia-smi", "--query-gpu=memory.used", "--format=csv,noheader,nounits",  "--id=" + str(device)])
    used_memory = int(used_memory.decode().split('\n')[0])

    percentage = round((used_memory / total_memory) * 100)
    return used_memory, total_memory, percentage

def gpu_memory_status(device):
    used, total, percentage = get_gpu_memory(device)
    print(f"Memoria usada: {used}")
    print(f"Memoria total: {total}")
    print(f"Porcentaje de memoria usada: {percentage}%")