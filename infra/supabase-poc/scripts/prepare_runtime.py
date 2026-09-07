#!/usr/bin/env python3
import hashlib
import shutil
import sys
import tarfile
import tempfile
import urllib.request
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
RUNTIME = ROOT / ".runtime"
PROJECT = RUNTIME / "project"


def load_provenance() -> dict[str, str]:
    values = {}
    for line in (ROOT / "provenance.env").read_text().splitlines():
        if line and not line.startswith("#"):
            key, value = line.split("=", 1)
            values[key] = value
    return values


def archive_sha(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def find_upstream_docker(extracted: Path) -> Path | None:
    docker_dirs = [path for path in extracted.glob("*/docker") if path.is_dir()]
    return docker_dirs[0] if len(docker_dirs) == 1 else None


def upstream_files_match(source: Path, target: Path) -> bool:
    for source_path in source.rglob("*"):
        relative = source_path.relative_to(source)
        target_path = target / relative
        if source_path.is_symlink():
            if not target_path.is_symlink() or target_path.readlink() != source_path.readlink():
                return False
        elif source_path.is_dir():
            if not target_path.is_dir() or target_path.is_symlink():
                return False
        elif source_path.is_file():
            if not target_path.is_file() or target_path.is_symlink():
                return False
            if archive_sha(source_path) != archive_sha(target_path):
                return False
        else:
            return False
    return True


def main() -> int:
    provenance = load_provenance()
    if PROJECT.exists():
        required = [PROJECT / ".env", PROJECT / "docker-compose.yml", PROJECT / "compose.poc.yml"]
        if all(path.is_file() for path in required):
            version_file = PROJECT / ".supabase-version"
            if not version_file.is_file() or version_file.read_bytes() != (ROOT / "provenance.env").read_bytes():
                print("ERROR: runtime provenance mismatch; run verified cleanup before preparing again", file=sys.stderr)
                return 2
            archive = RUNTIME / "upstream.tar.gz"
            if not archive.is_file() or archive_sha(archive) != provenance["SUPABASE_ARCHIVE_SHA256"]:
                print("ERROR: upstream archive checksum mismatch", file=sys.stderr)
                return 2
            with tempfile.TemporaryDirectory(dir=RUNTIME) as temp_dir:
                extracted = Path(temp_dir)
                with tarfile.open(archive) as bundle:
                    bundle.extractall(extracted, filter="data")
                upstream_docker = find_upstream_docker(extracted)
                if upstream_docker is None:
                    print("ERROR: reviewed upstream docker directory not found", file=sys.stderr)
                    return 2
                if not upstream_files_match(upstream_docker, PROJECT):
                    print("ERROR: cached upstream runtime differs from the verified archive; run verified cleanup", file=sys.stderr)
                    return 2
            shutil.copy2(ROOT / "compose.poc.yml", PROJECT / "compose.poc.yml")
            shutil.copy2(ROOT / ".poc-sentinel", PROJECT / ".poc-sentinel")
            print("Runtime already prepared; override refreshed and existing secrets preserved.")
            return 0
        print("ERROR: partial runtime exists; inspect it and run verified cleanup", file=sys.stderr)
        return 2

    RUNTIME.mkdir(mode=0o700, parents=True, exist_ok=True)
    archive = RUNTIME / "upstream.tar.gz"
    if not archive.exists():
        with urllib.request.urlopen(provenance["SUPABASE_ARCHIVE_URL"], timeout=120) as response:
            with tempfile.NamedTemporaryFile(dir=RUNTIME, delete=False) as temporary:
                shutil.copyfileobj(response, temporary)
                temp_path = Path(temporary.name)
        temp_path.replace(archive)
    actual_sha = archive_sha(archive)
    if actual_sha != provenance["SUPABASE_ARCHIVE_SHA256"]:
        print("ERROR: upstream archive checksum mismatch", file=sys.stderr)
        return 2

    with tempfile.TemporaryDirectory(dir=RUNTIME) as temp_dir:
        extracted = Path(temp_dir)
        with tarfile.open(archive) as bundle:
            bundle.extractall(extracted, filter="data")
        docker_dirs = [path for path in extracted.glob("*/docker") if path.is_dir()]
        if len(docker_dirs) != 1:
            print("ERROR: reviewed upstream docker directory not found", file=sys.stderr)
            return 2
        shutil.copytree(docker_dirs[0], PROJECT)

    shutil.copy2(ROOT / "compose.poc.yml", PROJECT / "compose.poc.yml")
    shutil.copy2(ROOT / "provenance.env", PROJECT / ".supabase-version")
    shutil.copy2(ROOT / ".poc-sentinel", PROJECT / ".poc-sentinel")
    import subprocess

    result = subprocess.run(
        [
            sys.executable,
            str(ROOT / "scripts" / "generate_env.py"),
            str(PROJECT / ".env.example"),
            str(PROJECT / ".env"),
        ],
        check=False,
        stdout=subprocess.DEVNULL,
    )
    if result.returncode != 0:
        return result.returncode
    (PROJECT / ".env").chmod(0o600)
    print("Prepared verified upstream runtime with private local secrets.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
