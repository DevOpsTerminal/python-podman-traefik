#!/bin/bash

# Array projektów
projects=("projekt1" "projekt2")
base_port=5001

# Build i uruchomienie każdego projektu
for i in "${!projects[@]}"; do
    project=${projects[i]}
    port=$((base_port + i))

    echo "Deploying $project on port $port..."

    cd ~/$project
    podman build -t $project .
    podman stop $project 2>/dev/null || true
    podman rm $project 2>/dev/null || true
    podman run -d --name $project -p $port:5000 $project

    echo "$project deployed on port $port"
done