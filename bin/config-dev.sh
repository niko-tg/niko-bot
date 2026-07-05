#
# Docker
#
readonly PREF="tnt"
readonly BASENAME="niko-bot"
readonly TARANTOOL_VERSION="3.7"
readonly APP_VERSION="2"

readonly BUILD_TAG="${TARANTOOL_VERSION}-${APP_VERSION}"
readonly DOCKER_CONTAINER_NAME="${PREF}-${BASENAME}"
readonly DOCKER_IMAGE="${PREF}-${BASENAME}:${BUILD_TAG}"

#
# Application
#
readonly INSTANCE_NAME="tnt-niko-bot"
readonly INSTANCE_DIR="$(pwd)/instances.enabled/${INSTANCE_NAME}"
