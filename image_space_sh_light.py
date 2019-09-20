import numpy as np
import glob
from PIL import Image
import sys

try:
    i = 0
    for lightname in sorted(glob.glob(sys.argv[1] + '*.npy')):
        print("rendering image with light: " + lightname)
        light = np.load(lightname)
        if light.shape[0] < light.shape[1]:
            light = light.T
        transport = np.load(sys.argv[2])["T"]
        print(light.shape)
        print(transport.shape)
        albedo = Image.open(sys.argv[3])
        shading = np.matmul(transport, light)
        rendering = albedo * shading
        image_output = Image.fromarray((rendering).astype(np.uint8))
        image_output.save(sys.argv[4] + ("frame%08d" % i) + "_relight2d.jpg")
        i += 1
except IndexError:
    print("Usage: python3 image_space_sh_light.py <directory with light data> <transport matrix> <albedo image> <output directory>")