#!/usr/bin/env bash

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

show_help() {
  cat << EOF
${BLUE}zsh Installation Script Testing Tool${NC}

Usage: ./test.sh [COMMAND] [SERVICE]

Commands:
  build [SERVICE]       Build Docker image(s). If SERVICE omitted, builds all.
  run [SERVICE]         Run interactive shell in container. If SERVICE omitted, prompts.
  test [SERVICE]        Run automated test in container
  clean                 Remove all containers and images
  list                  List available services

Services:
  - ubuntu-latest
  - ubuntu-focal
  - debian-bullseye
  - alpine

Examples:
  ./test.sh build ubuntu-latest
  ./test.sh run debian-bullseye
  ./test.sh test alpine
  ./test.sh clean

EOF
}

list_services() {
  echo -e "${BLUE}Available services:${NC}"
  echo "  - ubuntu-latest"
  echo "  - ubuntu-focal"
  echo "  - debian-bullseye"
  echo "  - alpine"
}

build_service() {
  local service=$1
  if [ -z "$service" ]; then
    echo -e "${YELLOW}Building all services...${NC}"
    docker-compose build
  else
    echo -e "${YELLOW}Building $service...${NC}"
    docker-compose build "$service"
  fi
}

run_interactive() {
  local service=$1
  if [ -z "$service" ]; then
    echo -e "${YELLOW}Which service do you want to test?${NC}"
    list_services
    read -p "Enter service name: " service
  fi

  echo -e "${GREEN}Starting interactive shell in $service...${NC}"
  echo -e "${BLUE}You can run: bash /tmp/install-zsh.sh${NC}"
  echo ""
  docker-compose run --rm "$service" /bin/bash
}

run_automated_test() {
  local service=$1
  if [ -z "$service" ]; then
    echo -e "${YELLOW}Testing all services...${NC}"
    services=("ubuntu-latest" "ubuntu-focal" "debian-bullseye" "alpine")
  else
    services=("$service")
  fi

  for svc in "${services[@]}"; do
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}Testing: $svc${NC}"
    echo -e "${BLUE}========================================${NC}"

    docker-compose run --rm "$svc" bash -c '
      echo "Input: none" | bash /tmp/install-zsh.sh
      if [ $? -eq 0 ]; then
        echo "Test passed"
      else
        echo "Test failed"
      fi
    '
  done
}

clean_all() {
  echo -e "${YELLOW}Removing containers and images...${NC}"
  docker-compose down --rmi all -v
  echo -e "${GREEN}Cleanup complete${NC}"
}

# Main logic
case "$1" in
  build)
    build_service "$2"
    ;;
  run)
    run_interactive "$2"
    ;;
  test)
    run_automated_test "$2"
    ;;
  clean)
    clean_all
    ;;
  list)
    list_services
    ;;
  help|--help|-h)
    show_help
    ;;
  *)
    show_help
    ;;
esac
