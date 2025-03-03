#!/bin/bash
set -e

echo "Start deploy.sh"

# Check if the required parameters are set
base_dir="$1"
rsync_path="$2"
releases_path="$3"
current_path="$4"
if [ -z "$base_dir" ]; then
  echo "base_dir is not set"
  exit 1
fi
if [ -z "$rsync_path" ]; then
  echo "rsync_path is not set"
  exit 1
fi
if [ -z "$releases_path" ]; then
  echo "releases_path is not set"
  exit 1
fi
if [ -z "$current_path" ]; then
  echo "current_path is not set"
  exit 1
fi

# Set the target folder
rsync_dir="$base_dir/$rsync_path"
releases_dir="$base_dir/$releases_path"
current_dir="$base_dir/$current_path"

# Check if the release folder exists
if [ ! -d "$rsync_dir" ]; then
  echo "rsync_dir does not exist, nothing to deploy"
  exit 1
fi

# Find the highest numbered folder in the base folder
latest_release=$(ls -d $releases_dir/*/ 2>/dev/null | grep -o '[0-9]*' | sort -n | tail -1)
if [ -z "$latest_release" ]; then
  latest_release=0
fi

# Increment the highest number by 1
new_release_path=$((latest_release + 1))

# Check if the releases folder exists, create it if it does not
if [ ! -d "$releases_dir" ]; then
  mkdir -p "$releases_dir"
  echo "Created releases folder: $releases_dir"
fi

# Rename temp_folder to the highest number
new_release_dir="$releases_dir/$new_release_path"
mv "$rsync_dir" "$new_release_dir"
echo "Moved $rsync_dir to $new_release_dir"

# Check if the release folder exists
shared_dir="$base_dir/shared"
if [ ! -d "$shared_dir" ]; then
  mkdir -p "$shared_dir"
  echo "Created share folder: $shared_dir"
fi

# Check if .env file exists, create from .env.example if it does not
if [ ! -f "$shared_dir/.env" ]; then
  cp "$new_release_dir/.env.example" "$shared_dir/.env"
  echo ".env file created from .env.example"
  ln -sfn "$shared_dir/.env" "$new_release_dir/.env"
  echo "Symlinked $shared_dir/.env to $new_release_dir/.env"
  /usr/bin/php8.3 "$new_release_dir/artisan" key:generate
  echo "Generated application key"
else
  ln -sfn "$shared_dir/.env" "$new_release_dir/.env"
  echo "Symlinked $shared_dir/.env to $new_release_dir/.env"
fi
rm -f "$new_release_dir/.env.example"

# Create the shared folders and symlink them to the release folder
folders=("storage/app" "storage/logs" "storage/framework/sessions" "storage/framework/cache")
for folder in "${folders[@]}"; do
  # Create the shared folders
  shared_sub_dir="$shared_dir/$folder"
  if [ ! -d "$shared_sub_dir" ]; then
    mkdir -p -m 775 "$shared_sub_dir"
    chown -R :www-data "$shared_sub_dir"
    chmod g+s "$shared_sub_dir"
    echo "Created shared folder: $shared_sub_dir"
  fi

  # Symlink the shared folders to the release folder
  new_sub_dir="$new_release_dir/$folder"
  if [ -d "$new_sub_dir" ]; then
    rm -rf "$new_sub_dir"
  fi
  ln -sfn "$shared_sub_dir" "$new_sub_dir"
  echo "Symlinked $shared_sub_dir to $new_sub_dir"
done

# Create the shared views folder and symlink it to the release folder
view_dir="$new_release_dir/storage/framework/views"
chmod -R 775 "$view_dir"
chown -R :www-data "$view_dir"
chmod g+s "$view_dir"
echo "Created shared folder: $view_dir"

# Symlink the storage folder to the release folder
ln -sfn "$shared_dir/storage/app/public" "$new_release_dir/public/storage"

# Run php artisan optimize and php artisan migrate on the target folder
/usr/bin/php8.3 "$new_release_dir/artisan" optimize
/usr/bin/php8.3 "$new_release_dir/artisan" migrate --force --graceful
echo "Run php artisan optimize and php artisan migrate on $new_release_dir"

# Symlink the target folder to the release folder
ln -sfn "$new_release_dir" "$current_dir"
echo "Symlinked $new_release_dir to $current_dir"

# Keep only the two latest releases
releases=($(ls -d $releases_dir/*/ | grep -o '[0-9]*' | sort -n))
if [ ${#releases[@]} -gt 2 ]; then
  for ((i=0; i<${#releases[@]}-2; i++)); do
    remove_release_path="${releases[i]}"
    remove_release_dir="$releases_dir/$remove_release_path"
    rm -rf "$remove_release_dir"
    echo "Removed old release folder: $remove_release_dir"
  done
fi

# Remove the temp folder
echo "Finished deploy.sh"
exit 0
