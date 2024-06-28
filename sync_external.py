import os
import sys
import subprocess
import urllib.request


def sync_lib(folder, git_path, commit_sha_or_branch_or_tag):
    print()
    print("-" * (2 * 4 + len(folder) + 2))
    print("----", folder, "----")
    print("-" * (2 * 4 + len(folder) + 2))
    print("Origin:", git_path)
    if not os.path.isdir(folder):
        os.system("git clone " + git_path)
    os.chdir(folder)
    os.system("git fetch")

    wanted_commit_sha = subprocess.run(
        ["git", "rev-parse", commit_sha_or_branch_or_tag],
        cwd=".",
        capture_output=True,
        text=True,
    ).stdout.strip()

    current_commit_sha = subprocess.run(
        ["git", "rev-parse", "HEAD"], cwd=".", capture_output=True, text=True
    ).stdout.strip()
    if current_commit_sha == wanted_commit_sha:
        print("Already at commit", commit_sha_or_branch_or_tag, wanted_commit_sha)
        os.chdir("..")
        return

    print("Current commit:", current_commit_sha)
    print("Wanted commit: ", commit_sha_or_branch_or_tag, wanted_commit_sha)
    if os.path.exists(os.path.join(".git", "refs", "heads", "main")):
        os.system("git checkout main")
    else:
        os.system("git checkout master")
    os.system("git pull")
    os.system("git submodule update --init --recursive")
    os.system("git checkout " + commit_sha_or_branch_or_tag)

    os.chdir("..")


def sync_zig_exe(build):
    print()
    print("-------------")
    print("---- ZIG ----")
    print("-------------")
    print("Downloading build", build)
    filename = "zig-windows-x86_64-" + build + ".zip"
    if os.path.isfile(filename):
        print("...already found: external/" + filename)
        return
    url = "https://ziglang.org/builds/" + filename
    urllib.request.urlretrieve(url, filename)
    print("...saved at: external/" + filename)
    print("Important: You need to copy this over your existing zig.exe")


def main():
    print("Syncing external...")
    external_dir = "external"
    if not os.path.isdir(external_dir):
        os.mkdir(external_dir)
    os.chdir(external_dir)

    sync_lib(
        "zig-args",
        "https://github.com/MasterQ32/zig-args.git",
        "872272205d95bdba33798c94e72c5387a31bc806",
    )
    sync_lib(
        "zig-gamedev",
        "https://github.com/Srekel/zig-gamedev.git",
        "181ef19e47ed02f32bcf3b5ea186587ab8dad24c",
    )
    sync_lib(
        "zigimg",
        "https://github.com/zigimg/zigimg.git",
        "563531ac08d70821e9679f4fe01273356b7d2a8a",
    )

    sync_zig_exe("0.13.0")

    os.chdir("..")
    print("Done syncing external!")


if __name__ == "__main__":
    main()
    print("Press enter...")
    input()
