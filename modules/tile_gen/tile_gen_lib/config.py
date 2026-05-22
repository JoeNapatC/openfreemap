import json
import os
import subprocess
from pathlib import Path


class Configuration:
    areas = ['planet', 'monaco']

    tile_gen_dir = Path('/data/ofm/tile_gen')

    tile_gen_bin = Path(__file__).parent.parent
    tile_gen_scripts_dir = tile_gen_bin / 'scripts'

    planetiler_bin = tile_gen_dir / 'planetiler'
    planetiler_path = planetiler_bin / 'planetiler.jar'

    runs_dir = tile_gen_dir / 'runs'

    # Support OFM_CONFIG_DIR env var override for Docker compatibility
    _config_dir_override = os.environ.get('OFM_CONFIG_DIR')
    if _config_dir_override:
        ofm_config_dir = Path(_config_dir_override)
    elif Path('/data/ofm').exists():
        ofm_config_dir = Path('/data/ofm/config')
    else:
        repo_root = Path(__file__).parent.parent.parent.parent
        ofm_config_dir = repo_root / 'config'

    config_json_path = ofm_config_dir / 'config.json'
    if config_json_path.exists():
        ofm_config = json.loads(config_json_path.read_text())
    else:
        ofm_config = {}

    rclone_config = ofm_config_dir / 'rclone.conf'
    rclone_bin = subprocess.run(['which', 'rclone'], capture_output=True, text=True).stdout.strip()


config = Configuration()

