import subprocess

def check_swap():
    """Check swap information."""
    try:
        swap_info = subprocess.check_output(['sudo', 'swapon', '--show']).decode().strip()
        print("Swap Information:")
        print(swap_info)
    except subprocess.CalledProcessError:
        print("No swap space is enabled yet on your system.")

def add_swap(size='1G'):
    """Add swap to your VPS."""
    try:
        # Create a swap file
        subprocess.run(['sudo', 'fallocate', '-l', size, '/swapfile'])
        # If 'fallocate' is not available, you can use 'dd' command instead
        # subprocess.run(['dd', 'if=/dev/zero', 'of=/swapfile', 'bs=1024', 'count=1048576'])

        # Set write permission
        subprocess.run(['sudo', 'chmod', '600', '/swapfile'])

        # Set up swap area
        subprocess.run(['sudo', 'mkswap', '/swapfile'])

        # Activate the swap file
        subprocess.run(['sudo', 'swapon', '/swapfile'])

        print("Swap file successfully added.")
    except subprocess.CalledProcessError as e:
        print("Error:", e)

def make_permanent():
    """Make the swap file permanent by adding an entry to /etc/fstab."""
    try:
        # Write to fstab using sudo
        with sudo():
            with open('/etc/fstab', 'a') as f:
                f.write('/swapfile swap swap defaults 0 0\n')
        print("Swap file added to /etc/fstab.")
    except Exception as e:
        print("Error:", e)

def main():
    check_swap()
    add_swap()
    make_permanent()
    check_swap()

if __name__ == "__main__":
    main()
