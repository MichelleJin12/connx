import os
import sys
from pathlib import Path
from glob import glob
import numpy as np
from run import run_direct, get_numpy_dtype, product

if len(sys.argv) != 3:
    print('Usage: {} [connx path] [connx home path]'.format(sys.argv[0]))
    sys.exit(0)

PASS = '\033[92m'
FAIL = '\033[91m'
END = '\033[0m'

CONNX = sys.argv[1]
HOME = sys.argv[2]

for path in Path(HOME + '/test').rglob('*.connx'):
    dataset = glob(os.path.join(path.parent, 'test_data_set_*'))

    for data in dataset:
        input_paths = glob(os.path.join(data, 'input-*.data'))
        input_paths.sort()
        output_paths = glob(os.path.join(data, 'output-*.data'))
        output_paths.sort()

        name = path.parent.name
        print('# Test:', name, end=' ')
        model_path = os.path.join(path.parent)

        outputs = run_direct(CONNX, model_path, input_paths)

        is_passed = True

        if len(outputs) != len(output_paths):
            if is_passed:
                print(f'{FAIL}Failed{END}')

            print('  Number of output count is different: inferenced: {}, reference: {}'
                  .format(len(outputs), len(output_paths)))

            is_passed = False

        for idx, (output, output_path) in enumerate(zip(outputs, output_paths)):
            tokens = os.path.basename(output_path).strip('.data').split('_')

            tokens.pop(0) # drop name
            
            # Parse dtype
            dtype = int(tokens.pop(0))
            dtype = get_numpy_dtype(dtype)
            if dtype != output.dtype:
                if is_passed:
                    print(f'{FAIL}Failed{END}')

                print('  data type of output[{}] is differ: inferenced: {}, reference: {}'
                      .format(idx, str(output.dtype), str(dtype)))

                is_passed = False
                continue

            # Parse ndim
            ndim = int(tokens.pop(0))
            if ndim != output.ndim:
                if is_passed:
                    print(f'{FAIL}Failed{END}')

                print('  ndim of output[{}] is differ: inferenced: {}, reference: {}'
                      .format(idx, str(output.ndim), str(ndim)))

                is_passed = False
                continue

            # Prase shape
            shape = tuple(( int(dim) for dim in tokens ))
            if shape != output.shape:
                if is_passed:
                    print(f'{FAIL}Failed{END}')

                print('  shape of output[{}] is differ: inferenced: {}, reference: {}'
                      .format(idx, str(output.shape), str(shape)))

                is_passed = False
                continue
            
            itemsize = np.dtype(dtype).itemsize
            total = product(shape)
            with open(output_path, 'rb') as file:
                ref = np.frombuffer(file.read(itemsize * total), dtype=dtype, count=product(shape)).reshape(shape)

            if not np.allclose(output, ref, atol=1e-07, rtol=0.001):
                if is_passed:
                    print(f'{FAIL}Failed{END}')

                print('  data of output[{}] is differ:'.format(idx))
                print('  ## Inferenced tensor')
                print(output)
                print('  ## Reference tensor')
                print(ref)

                is_passed = False
                continue

        if is_passed:
            print(f'{PASS}Passed{END}')
