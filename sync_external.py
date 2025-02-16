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
        "zigimg",
        "https://github.com/zigimg/zigimg.git",
        "563531ac08d70821e9679f4fe01273356b7d2a8a",
    )

    ##############
    ## ZIG-GAMEDEV
    sync_lib(
        "system_sdk",
        "https://github.com/zig-gamedev/system_sdk",
        "bf49d627a191e339f70e72668c8333717fb969b0",
    )
    sync_lib(
        "zglfw",
        "https://github.com/zig-gamedev/zglfw",
        "f3f35b36e3ae9cb6b85f39e15ab0336c1ee65b4b",
    )
    sync_lib(
        "zgui",
        "https://github.com/Srekel/zgui.git",
        "b5b29363a1a1db91519f0d94099c597e49eadfe9",
    )
    sync_lib(
        "zgpu",
        "https://github.com/zig-gamedev/zgpu.git",
        "bc10f874cf9c93e347c1298efba87be4f001fc9d",
    )
    sync_lib(
        "zpool",
        "https://github.com/zig-gamedev/zpool",
        "163b4ab18936a3d57b5d8375eba1284114402c80",
    )

    sync_zig_exe("0.14.0-dev.2577+271452d22")

    os.chdir("..")
    print("Done syncing external!")


if __name__ == "__main__":
    main()
    print("Press enter...")
    input()
