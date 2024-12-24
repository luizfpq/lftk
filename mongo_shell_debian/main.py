import subprocess

def run_command(command):
    """Run a shell command and return the output."""
    try:
        result = subprocess.run(command, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        return result.stdout.strip()
    except subprocess.CalledProcessError as e:
        print(f"Error running command '{' '.join(command)}': {e.stderr.strip()}")
        return None

# Step 1: Add MongoDB GPG Key
print("Adding MongoDB GPG Key...")
gpg_key_url = "https://www.mongodb.org/static/pgp/server-6.0.asc"
gpg_add_command = ["wget", "-qO", "-", gpg_key_url, "|", "sudo", "apt-key", "add", "-"]
run_command(["bash", "-c", ' '.join(gpg_add_command)])

# Step 2: Add MongoDB repository
print("Adding MongoDB repository...")
repo = "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/debian $(lsb_release -cs)/mongodb-org/6.0 main"
add_repo_command = ["sudo", "bash", "-c", f'echo "{repo}" > /etc/apt/sources.list.d/mongodb-org-6.0.list']
run_command(add_repo_command)

# Step 3: Update APT cache
print("Updating APT cache...")
update_cache_command = ["sudo", "apt", "update"]
run_command(update_cache_command)

# Step 4: Install MongoDB Shell (mongosh)
print("Installing MongoDB Shell (mongosh)...")
install_mongosh_command = ["sudo", "apt", "install", "-y", "mongodb-mongosh"]
run_command(install_mongosh_command)

# Step 5: Verify mongosh installation
print("Verifying MongoDB Shell installation...")
mongosh_version_command = ["mongosh", "--version"]
mongosh_version = run_command(mongosh_version_command)
if mongosh_version:
    print(f"MongoDB Shell installed successfully. Version: {mongosh_version}")
else:
    print("Failed to verify MongoDB Shell installation.")
