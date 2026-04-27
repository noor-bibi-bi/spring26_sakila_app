import yaml
import sys

try:
    with open('.github/workflows/deploy.yml', 'r') as f:
        yaml.safe_load(f)
    print("YAML is valid")
except yaml.YAMLError as exc:
    print(exc)
    sys.exit(1)
except Exception as e:
    print(e)
    sys.exit(1)
