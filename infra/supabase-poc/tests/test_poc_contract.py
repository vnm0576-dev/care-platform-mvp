import hashlib
import json
import os
import shutil
import stat
import subprocess
import tarfile
import tempfile
import textwrap
import unittest
from pathlib import Path


POC_ROOT = Path(__file__).resolve().parents[1]
PROJECT_NAME = "care-platform-supabase-poc"
POC_LABEL = "com.care-platform.synthetic-poc"
SELECTED_SERVICES = {
    "mailpit",
    "db",
    "auth",
    "rest",
    "meta",
    "studio",
    "api-gw",
    "supavisor",
}


class PocContractTest(unittest.TestCase):
    def make_cleanup_fixture(self, temp_dir):
        repo = Path(temp_dir) / "repo"
        poc = repo / "infra" / "supabase-poc"
        (repo / "supabase" / "migrations").mkdir(parents=True)
        poc.mkdir(parents=True)
        (repo / "README.md").write_text("fixture repository\n")
        (poc / "provenance.env").write_text("fixture=true\n")
        (poc / ".poc-sentinel").write_text(f"{PROJECT_NAME}:issue-74\n")
        shutil.copy2(POC_ROOT / "poc.sh", poc / "poc.sh")
        subprocess.run(
            ["git", "init", "--quiet", str(repo)],
            check=True,
            capture_output=True,
        )

        fake_bin = Path(temp_dir) / "bin"
        fake_bin.mkdir()
        fake_docker = fake_bin / "docker"
        fake_docker.write_text(
            "#!/bin/sh\n"
            "if [ \"$1\" = info ]; then exit 0; fi\n"
            "if [ \"$1\" = container ] && [ \"$2\" = inspect ]; then exit 1; fi\n"
            "if [ \"$2\" = ls ]; then exit 0; fi\n"
            "exit 99\n"
        )
        fake_docker.chmod(0o755)
        env = os.environ.copy()
        env["PATH"] = f"{fake_bin}:{env['PATH']}"
        return poc, env

    def write_fake_docker(self, env, source):
        fake_bin = Path(env["PATH"].split(":", 1)[0])
        fake_docker = fake_bin / "docker"
        fake_docker.write_text(textwrap.dedent(source).lstrip())
        fake_docker.chmod(0o755)

    def make_local_artifact(self, poc):
        (poc / ".runtime").mkdir(exist_ok=True)
        artifact = poc / ".runtime" / "keep"
        artifact.write_text("synthetic\n")
        (poc / "reports").mkdir(exist_ok=True)
        (poc / "reports" / "report.txt").write_text("synthetic\n")
        return artifact

    def run_destroy(self, poc, env):
        return subprocess.run(
            [str(poc / "poc.sh"), "destroy", "--confirm-destroy"],
            check=False,
            capture_output=True,
            text=True,
            env=env,
        )

    def make_runtime_fixture(self, temp_dir):
        poc = Path(temp_dir) / "supabase-poc"
        scripts = poc / "scripts"
        project = poc / ".runtime" / "project"
        source = Path(temp_dir) / "upstream-source" / "supabase-fixture" / "docker"
        scripts.mkdir(parents=True)
        project.mkdir(parents=True)
        (source / "volumes" / "api").mkdir(parents=True)
        shutil.copy2(POC_ROOT / "scripts" / "prepare_runtime.py", scripts / "prepare_runtime.py")
        shutil.copy2(POC_ROOT / "scripts" / "generate_env.py", scripts / "generate_env.py")
        (source / "docker-compose.yml").write_text("services: {}\n")
        (source / ".env.example").write_text("COMPOSE_FILE=docker-compose.yml\n")
        (source / "volumes" / "api" / "kong.yml").write_text("synthetic-upstream\n")
        archive = poc / ".runtime" / "upstream.tar.gz"
        with tarfile.open(archive, "w:gz") as bundle:
            bundle.add(source.parent, arcname=source.parent.name)
        archive_digest = hashlib.sha256(archive.read_bytes()).hexdigest()
        provenance = (
            "SUPABASE_REF=synthetic/ref\n"
            "SUPABASE_COMMIT=0000000000000000000000000000000000000000\n"
            "SUPABASE_ARCHIVE_URL=https://example.invalid/upstream.tar.gz\n"
            f"SUPABASE_ARCHIVE_SHA256={archive_digest}\n"
        )
        (poc / "provenance.env").write_text(provenance)
        (poc / "compose.poc.yml").write_text("services: {}\n")
        (poc / ".poc-sentinel").write_text(f"{PROJECT_NAME}:issue-74\n")
        shutil.copytree(source, project, dirs_exist_ok=True)
        (project / ".env").write_text("SYNTHETIC_SECRET=preserve-me\n")
        (project / ".env").chmod(0o600)
        shutil.copy2(poc / "compose.poc.yml", project / "compose.poc.yml")
        shutil.copy2(poc / ".poc-sentinel", project / ".poc-sentinel")
        (project / ".supabase-version").write_text(provenance)
        return poc, project, archive

    def run_prepare(self, poc):
        return subprocess.run(
            ["python3", str(poc / "scripts" / "prepare_runtime.py")],
            check=False,
            capture_output=True,
            text=True,
        )

    def test_provenance_pins_reviewed_upstream_archive(self):
        values = {}
        for line in (POC_ROOT / "provenance.env").read_text().splitlines():
            if line and not line.startswith("#"):
                key, value = line.split("=", 1)
                values[key] = value

        self.assertEqual(values["SUPABASE_REF"], "self-hosted/v0.8.0")
        self.assertEqual(
            values["SUPABASE_COMMIT"],
            "241bb11c0627f2981746d37033f57dbfa81d29b0",
        )
        self.assertEqual(
            values["SUPABASE_ARCHIVE_SHA256"],
            "77b4341e7b50df9c4da1cfbd012c04f90e1eef5695e09a727427dbd6ac9c569f",
        )

    def test_prepare_rejects_cached_runtime_with_stale_provenance(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            poc, project, _ = self.make_runtime_fixture(temp_dir)
            (project / ".supabase-version").write_text("SUPABASE_REF=stale\n")

            result = self.run_prepare(poc)

            self.assertEqual(result.returncode, 2)
            self.assertIn("runtime provenance mismatch", result.stderr)
            self.assertEqual(
                (project / ".env").read_text(),
                "SYNTHETIC_SECRET=preserve-me\n",
            )

    def test_prepare_rejects_cached_runtime_with_bad_archive_checksum(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            poc, project, archive = self.make_runtime_fixture(temp_dir)
            archive.write_bytes(archive.read_bytes() + b"tampered")

            result = self.run_prepare(poc)

            self.assertEqual(result.returncode, 2)
            self.assertIn("upstream archive checksum mismatch", result.stderr)
            self.assertEqual(
                (project / ".env").read_text(),
                "SYNTHETIC_SECRET=preserve-me\n",
            )

    def test_prepare_rejects_cached_runtime_with_modified_upstream_file(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            poc, project, _ = self.make_runtime_fixture(temp_dir)
            (project / "volumes" / "api" / "kong.yml").write_text("modified\n")

            result = self.run_prepare(poc)

            self.assertEqual(result.returncode, 2)
            self.assertIn("cached upstream runtime differs", result.stderr)
            self.assertEqual(
                (project / ".env").read_text(),
                "SYNTHETIC_SECRET=preserve-me\n",
            )

    def test_prepare_reuses_verified_runtime_and_ignores_additional_data(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            poc, project, _ = self.make_runtime_fixture(temp_dir)
            (project / "volumes" / "db" / "data").mkdir(parents=True)
            (project / "volumes" / "db" / "data" / "synthetic-row").write_text(
                "additional-runtime-data\n"
            )

            result = self.run_prepare(poc)

            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("existing secrets preserved", result.stdout)
            self.assertEqual(
                (project / ".env").read_text(),
                "SYNTHETIC_SECRET=preserve-me\n",
            )

    def test_rendered_compose_contract(self):
        if shutil.which("docker") is None:
            self.skipTest("Docker Compose CLI is unavailable")

        upstream = textwrap.dedent(
            """
            name: supabase
            services:
              studio:
                container_name: supabase-studio
                image: example.invalid/studio:latest
                depends_on: {meta: {condition: service_started}}
              api-gw:
                container_name: supabase-envoy
                image: example.invalid/gateway:latest
                depends_on: {studio: {condition: service_started}}
                ports: ["0.0.0.0:8000:8000"]
              auth:
                container_name: supabase-auth
                image: example.invalid/auth:latest
                depends_on: {db: {condition: service_started}}
              rest:
                container_name: supabase-rest
                image: example.invalid/rest:latest
                depends_on: {db: {condition: service_started}}
              meta:
                container_name: supabase-meta
                image: example.invalid/meta:latest
                depends_on: {db: {condition: service_started}}
              db:
                container_name: supabase-db
                image: example.invalid/db:latest
                volumes: ["db-config:/etc/postgresql-custom"]
              supavisor:
                container_name: supabase-pooler
                image: example.invalid/pooler:latest
                depends_on: {db: {condition: service_started}}
                ports: ["0.0.0.0:5432:5432", "0.0.0.0:6543:6543"]
              inactive:
                image: example.invalid/inactive:latest
            volumes:
              db-config: {}
            """
        )
        with tempfile.TemporaryDirectory() as temp_dir:
            upstream_path = Path(temp_dir) / "docker-compose.yml"
            upstream_path.write_text(upstream)
            result = subprocess.run(
                [
                    "docker",
                    "compose",
                    "--project-directory",
                    temp_dir,
                    "--file",
                    str(upstream_path),
                    "--file",
                    str(POC_ROOT / "compose.poc.yml"),
                    "config",
                    "--format",
                    "json",
                ],
                check=False,
                capture_output=True,
                text=True,
            )
        self.assertEqual(result.returncode, 0, result.stderr)
        rendered = json.loads(result.stdout)
        self.assertEqual(rendered["name"], PROJECT_NAME)

        services = rendered["services"]
        images = {
            line
            for line in (POC_ROOT / "images.lock").read_text().splitlines()
            if line and not line.startswith("#")
        }
        self.assertEqual(len(images), len(SELECTED_SERVICES))
        for service_name in SELECTED_SERVICES:
            service = services[service_name]
            self.assertIn(service["image"], images)
            self.assertRegex(service["image"], r":.+@sha256:[0-9a-f]{64}$")
            self.assertTrue(service["container_name"].startswith("care-platform-poc-"))
            self.assertEqual(service["labels"][POC_LABEL], "issue-74")

        expected_dependencies = {
            "studio": {"meta"},
            "api-gw": {"studio"},
            "auth": {"db", "mailpit"},
            "rest": {"db"},
            "meta": {"db"},
            "supavisor": {"db"},
        }
        for service_name, dependencies in expected_dependencies.items():
            self.assertTrue(dependencies.issubset(services[service_name]["depends_on"]))

        published = []
        for service_name in SELECTED_SERVICES:
            published.extend(services[service_name].get("ports", []))
        self.assertEqual(len(published), 4)
        self.assertTrue(all(port["host_ip"] == "127.0.0.1" for port in published))
        self.assertEqual(rendered["networks"]["default"]["labels"][POC_LABEL], "issue-74")
        self.assertEqual(rendered["volumes"]["db-config"]["labels"][POC_LABEL], "issue-74")

    def test_every_active_image_is_recorded_once(self):
        images = [
            line
            for line in (POC_ROOT / "images.lock").read_text().splitlines()
            if line and not line.startswith("#")
        ]
        self.assertEqual(len(images), 8)
        self.assertEqual(len(set(images)), len(images))
        for image in images:
            self.assertRegex(image, r":.+@sha256:[0-9a-f]{64}$")
            self.assertIn(image, (POC_ROOT / "compose.poc.yml").read_text())

    def test_cleanup_is_uniquely_scoped_and_fail_closed(self):
        text = (POC_ROOT / "poc.sh").read_text()
        self.assertIn('POC_PROJECT_NAME="care-platform-supabase-poc"', text)
        self.assertIn('--project-name "$POC_PROJECT_NAME"', text)
        self.assertIn("realpath", text)
        self.assertIn("POC_SENTINEL", text)
        self.assertIn("com.docker.compose.project", text)
        self.assertIn(POC_LABEL, text)
        self.assertIn("verify_cleanup", text)
        self.assertNotIn("--remove-orphans", text)

    def test_migrate_rejects_partial_marker_and_requires_verified_rebuild(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            poc, env = self.make_cleanup_fixture(temp_dir)
            project = poc / ".runtime" / "project"
            project.mkdir(parents=True)
            (project / ".env").write_text("synthetic=true\n")
            (project / ".env").chmod(0o600)
            (project / "docker-compose.yml").write_text("services: {}\n")
            (project / "compose.poc.yml").write_text("services: {}\n")
            (project / ".poc-sentinel").write_text(
                f"{PROJECT_NAME}:issue-74\n"
            )
            reports = poc / "reports"
            reports.mkdir()
            partial_marker = reports / "migrations-applied.txt.tmp"
            partial_marker.write_text("0001_synthetic.sql\n")

            result = subprocess.run(
                [str(poc / "poc.sh"), "migrate"],
                check=False,
                capture_output=True,
                text=True,
                env=env,
            )

            self.assertEqual(result.returncode, 2)
            self.assertTrue(partial_marker.exists())
            self.assertIn("partial migration run", result.stderr)
            self.assertIn("verified destroy", result.stderr)
            self.assertNotIn("Applying", result.stdout)

    def test_destroy_cleans_partial_local_state_and_verifies_absence(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            poc, env = self.make_cleanup_fixture(temp_dir)
            (poc / ".runtime" / "project").mkdir(parents=True)
            (poc / ".runtime" / "project" / "partial").write_text("synthetic\n")
            (poc / "reports").mkdir()
            (poc / "reports" / "report.txt").write_text("synthetic\n")

            result = subprocess.run(
                [str(poc / "poc.sh"), "destroy", "--confirm-destroy"],
                check=False,
                capture_output=True,
                text=True,
                env=env,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertFalse((poc / ".runtime").exists())
            self.assertFalse((poc / "reports").exists())
            self.assertIn("Partial runtime detected", result.stderr)

    def test_destroy_rejects_invalid_sentinel_without_deleting(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            poc, env = self.make_cleanup_fixture(temp_dir)
            (poc / ".runtime").mkdir()
            artifact = poc / ".runtime" / "keep"
            artifact.write_text("synthetic\n")
            (poc / ".poc-sentinel").write_text("wrong-project\n")

            result = subprocess.run(
                [str(poc / "poc.sh"), "destroy", "--confirm-destroy"],
                check=False,
                capture_output=True,
                text=True,
                env=env,
            )
            self.assertEqual(result.returncode, 2)
            self.assertTrue(artifact.exists())
            self.assertIn("sentinel content is invalid", result.stderr)

    def test_destroy_refuses_post_delete_listing_failure_and_preserves_artifacts(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            poc, env = self.make_cleanup_fixture(temp_dir)
            artifact = self.make_local_artifact(poc)
            state = Path(temp_dir) / "list-count"
            env["FAKE_DOCKER_STATE"] = str(state)
            self.write_fake_docker(
                env,
                """
                #!/usr/bin/python3
                import os
                import pathlib
                import sys

                args = sys.argv[1:]
                if args == ["info"]:
                    raise SystemExit(0)
                if len(args) >= 2 and args[1] == "inspect":
                    raise SystemExit(1)
                if len(args) >= 2 and args[1] == "ls":
                    if any("com.docker.compose.project" in arg for arg in args):
                        state = pathlib.Path(os.environ["FAKE_DOCKER_STATE"])
                        count = int(state.read_text()) if state.exists() else 0
                        state.write_text(str(count + 1))
                        if count == 6:
                            raise SystemExit(42)
                    raise SystemExit(0)
                raise SystemExit(99)
                """,
            )

            result = self.run_destroy(poc, env)

            self.assertNotEqual(result.returncode, 0)
            self.assertTrue(artifact.exists())
            self.assertTrue((poc / "reports" / "report.txt").exists())
            self.assertIn("failed to verify project container cleanup", result.stderr)

    def test_destroy_refuses_project_only_foreign_resource_and_preserves_artifacts(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            poc, env = self.make_cleanup_fixture(temp_dir)
            artifact = self.make_local_artifact(poc)
            self.write_fake_docker(
                env,
                f"""
                #!/bin/sh
                if [ "$1" = info ]; then exit 0; fi
                if [ "$1" = container ] && [ "$2" = ls ]; then
                  case "$*" in *com.docker.compose.project*) echo foreign-id;; esac
                  exit 0
                fi
                if [ "$1" = container ] && [ "$2" = inspect ]; then
                  case "$*" in *foreign-id*) printf '%s|\\n' '{PROJECT_NAME}'; exit 0;; esac
                  exit 1
                fi
                if [ "$2" = ls ]; then exit 0; fi
                exit 99
                """,
            )

            result = self.run_destroy(poc, env)

            self.assertNotEqual(result.returncode, 0)
            self.assertTrue(artifact.exists())
            self.assertTrue((poc / "reports" / "report.txt").exists())
            self.assertIn("unverified container 'foreign-id'", result.stderr)

    def test_destroy_refuses_labels_changed_before_delete_and_preserves_artifacts(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            poc, env = self.make_cleanup_fixture(temp_dir)
            artifact = self.make_local_artifact(poc)
            state = Path(temp_dir) / "inspect-count"
            env["FAKE_DOCKER_STATE"] = str(state)
            self.write_fake_docker(
                env,
                f"""
                #!/usr/bin/python3
                import os
                import pathlib
                import sys

                args = sys.argv[1:]
                if args == ["info"]:
                    raise SystemExit(0)
                if args[:2] == ["container", "ls"]:
                    if any("com.docker.compose.project" in arg for arg in args):
                        print("owned-id")
                    raise SystemExit(0)
                if args[:2] in (["network", "ls"], ["volume", "ls"]):
                    raise SystemExit(0)
                if args[:2] == ["container", "inspect"]:
                    if args[-1] != "owned-id":
                        raise SystemExit(1)
                    state = pathlib.Path(os.environ["FAKE_DOCKER_STATE"])
                    count = int(state.read_text()) if state.exists() else 0
                    state.write_text(str(count + 1))
                    if count == 0:
                        print("{PROJECT_NAME}|issue-74")
                    else:
                        print("{PROJECT_NAME}|changed")
                    raise SystemExit(0)
                if args[:2] == ["container", "rm"]:
                    pathlib.Path(os.environ["FAKE_DOCKER_STATE"] + ".removed").write_text("yes")
                    raise SystemExit(0)
                raise SystemExit(99)
                """,
            )

            result = self.run_destroy(poc, env)

            self.assertNotEqual(result.returncode, 0)
            self.assertTrue(artifact.exists())
            self.assertTrue((poc / "reports" / "report.txt").exists())
            self.assertFalse(Path(f"{state}.removed").exists())
            self.assertIn("unverified container 'owned-id'", result.stderr)

    def test_destroy_refuses_reserved_foreign_network_and_preserves_artifacts(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            poc, env = self.make_cleanup_fixture(temp_dir)
            artifact = self.make_local_artifact(poc)
            self.write_fake_docker(
                env,
                """
                #!/bin/sh
                if [ "$1" = info ]; then exit 0; fi
                if [ "$1" = container ] && [ "$2" = inspect ]; then exit 1; fi
                if [ "$1" = container ] && [ "$2" = ls ]; then exit 0; fi
                if [ "$1" = network ] && [ "$2" = inspect ]; then
                  case "$*" in
                    *care-platform-supabase-poc_default*) printf 'foreign|foreign\\n'; exit 0;;
                  esac
                  exit 1
                fi
                if [ "$1" = network ] && [ "$2" = ls ]; then exit 0; fi
                if [ "$1" = volume ] && [ "$2" = inspect ]; then exit 1; fi
                if [ "$1" = volume ] && [ "$2" = ls ]; then exit 0; fi
                exit 99
                """,
            )

            result = self.run_destroy(poc, env)

            self.assertNotEqual(result.returncode, 0)
            self.assertTrue(artifact.exists())
            self.assertTrue((poc / "reports" / "report.txt").exists())
            self.assertIn("reserved PoC network", result.stderr)

    def test_privileged_delete_fallback_uses_only_canonical_targets(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            poc, env = self.make_cleanup_fixture(temp_dir)
            (poc / ".runtime").mkdir()
            (poc / "reports").mkdir()
            fake_bin = Path(env["PATH"].split(":", 1)[0])
            fake_rm = fake_bin / "rm"
            fake_rm.write_text("#!/bin/sh\nexit 1\n")
            fake_rm.chmod(0o755)
            fake_sudo = fake_bin / "sudo"
            fake_sudo.write_text(
                "#!/usr/bin/python3\n"
                "import os, subprocess, sys\n"
                "expected = ['-n', 'rm', '-rf', '--', os.environ['EXPECTED_RUNTIME'], os.environ['EXPECTED_REPORTS']]\n"
                "if sys.argv[1:] != expected:\n"
                "    raise SystemExit(97)\n"
                "raise SystemExit(subprocess.run(['/bin/rm', '-rf', '--', expected[-2], expected[-1]]).returncode)\n"
            )
            fake_sudo.chmod(0o755)
            env["EXPECTED_RUNTIME"] = str(poc / ".runtime")
            env["EXPECTED_REPORTS"] = str(poc / "reports")

            result = subprocess.run(
                [str(poc / "poc.sh"), "destroy", "--confirm-destroy"],
                check=False,
                capture_output=True,
                text=True,
                env=env,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertFalse((poc / ".runtime").exists())
            self.assertFalse((poc / "reports").exists())

    def test_env_generation_is_silent_private_and_fail_closed(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            temp = Path(temp_dir)
            upstream = temp / ".env.example"
            target = temp / ".env"
            upstream.write_text(
                "POSTGRES_PASSWORD=your-super-secret-and-long-postgres-password\n"
                "JWT_SECRET=your-super-secret-jwt-token-with-at-least-32-characters-long\n"
                "ANON_KEY=eyJhbG...u4GE\n"
                "SERVICE_ROLE_KEY=eyJhbG...Vt4Q\n"
                "DASHBOARD_PASSWORD=this_password_is_insecure_and_should_be_updated\n"
                "SECRET_KEY_BASE=default\n"
                "REALTIME_DB_ENC_KEY=supabaserealtime\n"
                "VAULT_ENC_KEY=your-32-character-encryption-key\n"
                "PG_META_CRYPTO_KEY=your-encryption-key-32-chars-min\n"
                "LOGFLARE_PUBLIC_ACCESS_TOKEN=default\n"
                "LOGFLARE_PRIVATE_ACCESS_TOKEN=default\n"
                "S3_PROTOCOL_ACCESS_KEY_ID=default\n"
                "S3_PROTOCOL_ACCESS_KEY_SECRET=default\n"
                "MINIO_ROOT_PASSWORD=secret1234\n"
                "ENABLE_EMAIL_AUTOCONFIRM=false\n"
                "ENABLE_PHONE_SIGNUP=true\n"
                "SMTP_HOST=supabase-mail\n"
                "COMPOSE_FILE=docker-compose.yml\n"
            )
            result = subprocess.run(
                [
                    "python3",
                    str(POC_ROOT / "scripts" / "generate_env.py"),
                    str(upstream),
                    str(target),
                ],
                check=False,
                capture_output=True,
                text=True,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout, "")
            self.assertEqual(stat.S_IMODE(target.stat().st_mode), 0o600)
            generated = target.read_text()
            for forbidden in (
                "your-super-secret",
                "eyJhbG...",
                "this_password_is_insecure",
                "secret1234",
            ):
                self.assertNotIn(forbidden, generated)
            self.assertIn("ENABLE_EMAIL_AUTOCONFIRM=true", generated)
            self.assertIn("ENABLE_PHONE_SIGNUP=false", generated)
            self.assertIn("SMTP_HOST=mailpit", generated)
            self.assertIn(
                "COMPOSE_FILE=docker-compose.yml:compose.poc.yml", generated
            )

    def test_smoke_script_uses_real_auth_and_rest_boundaries(self):
        text = (POC_ROOT / "scripts" / "smoke_test.py").read_text()
        for endpoint in (
            "/auth/v1/signup",
            "/auth/v1/token?grant_type=password",
            "/rest/v1/caregiver_profiles",
            "/rest/v1/client_requests",
            "/rest/v1/rpc/submit_caregiver_profile",
            "/rest/v1/rpc/bootstrap_admin",
            "/rest/v1/rpc/moderate_caregiver_profile",
            "/rest/v1/approved_caregiver_profiles",
        ):
            self.assertIn(endpoint, text)
        self.assertNotIn("print(access_token", text)
        self.assertNotIn("print(service_role", text)
        self.assertIn("len(set(ids)) == 5", text)
        self.assertGreaterEqual(
            text.count('for actor, token in (("caregiver", caregiver_token), ("client", client_token))'),
            2,
        )
        self.assertIn('f"ordinary {actor} cannot bootstrap an administrator"', text)
        self.assertIn('f"ordinary {actor} cannot moderate a profile"', text)
        for assertion in (
            "cross-user update leaves caregiver profile unchanged",
            "cross-user delete leaves caregiver profile unchanged",
            "anonymous raw caregiver access is denied",
        ):
            self.assertIn(assertion, text)

    def test_smoke_covers_client_request_crud_and_cross_user_boundaries(self):
        text = (POC_ROOT / "scripts" / "smoke_test.py").read_text()
        self.assertIn("/rest/v1/client_requests", text)
        self.assertIn('accounts["other-client"]', text)
        self.assertIn("len(set(ids)) == 5", text)
        for assertion in (
            "client creates own synthetic request over REST",
            "client reads own synthetic request over REST",
            "denied client request updates leave owner state unchanged",
            "denied client request deletes leave owner state unchanged",
            "client updates own synthetic request over REST",
            "client deletes own synthetic request over REST",
            "owner read confirms synthetic client request deletion",
        ):
            self.assertIn(assertion, text)
        for operation in ("create", "read", "update", "delete"):
            self.assertIn(f'f"{{actor}} cannot {operation} client request', text)
        for health_flag in (
            "dementia_case",
            "bedridden_case",
            "stroke_case",
            "heart_attack_case",
            "trauma_case",
        ):
            self.assertIn(f'"{health_flag}": False', text)

    def test_approved_projection_query_targets_new_questionnaire(self):
        text = (POC_ROOT / "scripts" / "smoke_test.py").read_text()
        projection_query = text[text.index("query = urllib.parse.urlencode"):]
        self.assertIn('"id": f"eq.{encoded}"', projection_query)

    def test_smoke_denies_direct_status_write_while_questionnaire_is_draft(self):
        text = (POC_ROOT / "scripts" / "smoke_test.py").read_text()
        submission = text.index("caregiver submits questionnaire through protected RPC")
        draft_phase = text[:submission]
        self.assertIn("owner cannot mutate draft moderation status directly", draft_phase)
        self.assertIn("denied direct status write leaves questionnaire in draft", draft_phase)

    def test_smoke_rechecks_raw_caregiver_isolation_after_approval(self):
        text = (POC_ROOT / "scripts" / "smoke_test.py").read_text()
        approval = text.index("admin moderates through protected RPC")
        post_approval = text[approval:]
        self.assertIn("client raw caregiver read remains denied after approval", post_approval)
        self.assertIn(
            "cross-caregiver raw read remains denied after approval",
            post_approval,
        )

    def test_runtime_and_secret_files_are_ignored(self):
        text = (POC_ROOT / ".gitignore").read_text().splitlines()
        self.assertIn(".runtime/", text)
        self.assertIn("reports/", text)
        self.assertIn(".env", text)


if __name__ == "__main__":
    unittest.main()
