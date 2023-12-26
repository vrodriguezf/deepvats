# -*- coding: utf-8 -*-
"""memory.ipynb

Automatically generated.

Original file is located at:
    /home/macu/work/nbs_pipeline/utils_nbs/memory.ipynb
"""

import subprocess
import psutil

def get_gpu_memory(device=0):
    total_memory = subprocess.check_output(["nvidia-smi", "--query-gpu=memory.total", "--format=csv,noheader,nounits", "--id=" + str(device)])
    total_memory = int(total_memory.decode().split('\n')[0])
    used_memory = subprocess.check_output(["nvidia-smi", "--query-gpu=memory.used", "--format=csv,noheader,nounits",  "--id=" + str(device)])
    used_memory = int(used_memory.decode().split('\n')[0])

    percentage = round((used_memory / total_memory) * 100)
    return used_memory, total_memory, percentage

def color_for_percentage(percentage):
    if percentage < 20:
        return "\033[90m"  # Gray
    elif percentage < 40:
        return "\033[94m"  # Blue
    elif percentage < 60:
        return "\033[92m"  # Green
    elif percentage < 80:
        return "\033[93m"  # Orange
    else:
        return "\033[91m"  # Red

def create_bar(percentage, color_code, length=20):
    filled_length = int(length * percentage // 100)
    bar = "█" * filled_length + "-" * (length - filled_length)
    return color_code + bar + "\033[0m"  # Apply color and reset after bar

def gpu_memory_status(device=0):
    used, total, percentage = get_gpu_memory(device)
    color_code = color_for_percentage(percentage)
    bar = create_bar(percentage, color_code)
    print(f"Used mem: {used}")
    print(f"Used mem: {total}")
    print(f"Memory Usage: [{bar}] {color_code}{percentage}%\033[0m")

gpu_memory_status()

def get_cpu_memory():
    mem = psutil.virtual_memory()
    total_memory = mem.total // (1024**2)  # Convertir a MB
    used_memory = (mem.total - mem.available) // (1024**2)  # Convertir a MB
    percentage = mem.percent
    return used_memory, total_memory, percentage

def cpu_memory_status():
    used, total, percentage = get_cpu_memory()
    color_code = color_for_percentage(percentage)
    bar = create_bar(percentage, color_code)
    print(f"Used mem: {used}")
    print(f"Used mem: {total}")
    print(f"Memory Usage: [{bar}] {color_code}{percentage}%\033[0m")

cpu_memory_status()