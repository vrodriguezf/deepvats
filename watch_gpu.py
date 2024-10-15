import GPUtil
import torch
from torch import cuda
import sys

def print_gpu_usage(gpu_indices=[]):
    # Imprimir el uso de GPU
    GPUs = GPUtil.getGPUs()
    used_memory = 0
    free_memory = 0
    total_memory = 0
    available_indices = set(range(len(GPUs)))
    selected_indices = available_indices.intersection(gpu_indices)
    for index in selected_indices:
        gpu = GPUs[index]
        used_memory = used_memory + gpu.memoryUsed
        free_memory = free_memory + gpu.memoryFree
        total_memory = total_memory + gpu.memoryTotal
        print(f"GPU {gpu.id}: {gpu.name}")
        print(f"Memory Free: {gpu.memoryFree}MB / {gpu.memoryTotal}MB")
        print(f"Memory Used: {gpu.memoryUsed}MB")
        print(f"GPU Load: {gpu.load*100}%")
        print("-" * 40)
    return used_memory, free_memory, total_memory
def list_tensors():
    # Listar todos los tensores en la GPU
    for obj in gc.get_objects():
        if torch.is_tensor(obj):
            if obj.is_cuda:
                print(f"Tensor: {type(obj)}, Size: {obj.size()}, Memory: {obj.element_size() * obj.nelement() / (1024**2)} MB")

def list_all_objects(verbose = 0):
    object_sizes = []
    for obj in gc.get_objects():
        try:
            size = sys.getsizeof(obj)
            object_sizes.append((type(obj), size))
            if verbose > 1:
                print(f"Object: {type(obj)}, Size: {size} bytes")

        except Exception as e:
            if verbose > 1:
	            print(f"Could not get size for object {type(obj)}: {e}")
            pass
    object_sizes.sort(key=lambda x: x[1], reverse=True)
    top_5 = object_sizes[:5]
    rest_sum = sum(size for _, size in object_sizes[5:])
    return top_5, rest_sum
if __name__ == "__main__":
    import time
    import gc
    gpu_indices = list(map(int, sys.argv[1:])) if len(sys.argv) > 1 else []

    while True:
        print("Checking GPU Memory Usage...")
        used_memory, free_memory, total_memory = print_gpu_usage(gpu_indices)

        #print("\nListing Tensors in GPU:")
        #list_tensors()
        print("\nListing Largests objects in memory:")
        top_5_objects, rest_sum = list_all_objects() 
        
        print("\nTop 5 Largest Objects in Memory:")
        print("\n| Object Type | Size (MB) | % of Used Memory | % of Total Memory |")
        print("|-------------|-----------|------------------|-------------------|")
        for obj_type, size in top_5_objects:
            size_mb = size / (1024 ** 2)
            perc_used_memory = (size_mb / used_memory) * 100 if used_memory else 0
            perc_total_memory = (size_mb / total_memory) * 100 if total_memory else 0
            print(f"| {str(obj_type):<12} | {size_mb:<9.2f} | {perc_used_memory:<16.2f}% | {perc_total_memory:<17.2f}% |")

        # Imprimir la suma del tamaño del resto de los objetos
        rest_size_mb = rest_sum / (1024 ** 2)
        perc_rest_used_memory = (rest_size_mb / used_memory) * 100 if used_memory else 0
        perc_rest_total_memory = (rest_size_mb / total_memory) * 100 if total_memory else 0
        print(f"| Rest of Objects | {rest_size_mb:<9.2f} | {perc_rest_used_memory:<16.2f}% | {perc_rest_total_memory:<17.2f}% |")

        # Resumen de la memoria total
        print("\nGPU Memory Summary:")
        print(f"Used Memory: {used_memory} MB ({(used_memory / total_memory * 100):.2f}% of Total)")
        print(f"Free Memory: {free_memory} MB ({(free_memory / total_memory * 100):.2f}% of Total)")
        print(f"Total Memory: {total_memory} MB")

        time.sleep(10)  # Refrescar cada 10 segundos
