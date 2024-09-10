import subprocess

def run_script(slp):
    command = ['python', 'scripts/train.py', '--slp', str(slp)]
    
    # Run the script as a subprocess
    process = subprocess.Popen(command)

    # Wait for the script to complete
    process.wait()

if __name__ == "__main__":
    slp_values = [1.0, 2.0, 4.0, 6.0, 8.0, 12.0, 16.0, 32.0, 48.0]

    for slp_val in slp_values:
        run_script(slp_val)

