#!/bin/bash
set -e

echo "Start ..."

# Check if the required parameters are set
base_folder="$1"
temp_folder="$2"
release_folder="$3"
if [ -z "$base_folder" ]; then
  echo "BASE_FOLDER is not set"
  exit 1
fi
if [ -z "$release_folder" ]; then
  echo "RELEASE_FOLDER is not set"
  exit 1
fi
if [ -z "$temp_folder" ]; then
  echo "TEMP_FOLDER is not set"
  exit 1
fi
release_folder="$base_folder$release_folder"

# Check if the release folder exists
temp_folder="$base_folder$temp_folder"
if [ ! -d "$temp_folder" ]; then
  echo "TEMP_FOLDER does not exist, nothing to deploy"
  exit 1
fi

# Find the highest numbered folder in the base folder
highest_number=$(ls -d $base_folder/*/ 2>/dev/null | grep -o '[0-9]*' | sort -n | tail -1)
if [ -z "$highest_number" ]; then
  highest_number=0
fi

# Increment the highest number by 1
new_number=$((highest_number + 1))

# Rename temp_folder to the highest number
target_folder="$base_folder/$new_number"
mv "$temp_folder" "$target_folder"
echo "Moved $temp_folder to $target_folder"

# Check if the release folder exists
share_folder="$base_folder/share"
if [ ! -d "$share_folder" ]; then
  mkdir -p "$share_folder"
  echo "Created share folder: $share_folder"
fi

# Check if .env file exists, create from .env.example if it does not
if [ ! -f "$share_folder/.env" ]; then
  cp "$target_folder/.env.example" "$share_folder/.env"
  echo ".env file created from .env.example"
  ln -sfn "$share_folder/.env" "$target_folder/.env"
  /usr/bin/php8.3 "$target_folder/artisan" key:generate
  echo "Symlinked $share_folder/.env to $target_folder/.env"
else
  ln -sfn "$share_folder/.env" "$target_folder/.env"
  echo "Symlinked $share_folder/.env to $target_folder/.env"
fi
rm -f "$target_folder/.env.example"

# Check if the required folders exist, copy from target_folder if they do not
folders=("storage/app" "storage/logs" "storage/framework/sessions" "storage/framework/cache")
for folder in "${folders[@]}"; do
  if [ ! -d "$share_folder/$folder" ]; then
    mkdir -p -m 775 "$share_folder/$folder"
    chown -R :www-data "$share_folder/$folder"
    echo "Copied $folder from $target_folder to $share_folder"
  fi
done
chmod -R 775 "$target_folder/storage/framework"
chown -R :www-data "$target_folder/storage/framework"

# Symlink the folders to the target_folder, overriding if they exist
for folder in "${folders[@]}"; do
  target_path="$target_folder/$folder"
  share_path="$share_folder/$folder"
  if [ -d "$target_path" ]; then
    rm -rf "$target_path"
  fi
  ln -sfn "$share_path" "$target_path"
  echo "Symlinked $share_path to $target_path"
done

# Run php artisan optimize and php artisan migrate on the target folder
/usr/bin/php8.3 "$target_folder/artisan" storage:link
/usr/bin/php8.3 "$target_folder/artisan" optimize
/usr/bin/php8.3 "$target_folder/artisan" migrate --force --graceful
echo "Run php artisan optimize and php artisan migrate on $target_folder"

# Symlink the target folder to the release folder
ln -sfn "$target_folder" "$release_folder"
echo "Symlinked $target_folder to $release_folder"

# Keep only the two latest releases
releases=($(ls -d $base_folder/*/ | grep -o '[0-9]*' | sort -n))
if [ ${#releases[@]} -gt 2 ]; then
  for ((i=0; i<${#releases[@]}-2; i++)); do
    old_release_folder="${releases[i]}"
    remove_release_folder="$base_folder/$old_release_folder"
    rm -rf "$remove_release_folder"
    echo "Removed old release folder: $remove_release_folder"
  done
fi

# Remove the temp folder
echo "Finished"
