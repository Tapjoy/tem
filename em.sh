# EM is a utility for managing multiple environment profiles. It handles loading a default set of variables, ensures
# the litany of variables used by the tools are set and provides a mechanism for quickly switching between profiles.

$SHELL --version | grep 'bash, version 3'
if [ $? -eq 0 ]; then
  echo "TEM does not support Bash version 3! Follow the upgrade instructions in the README to upgrade to version 4!"
  return
fi

# Common ENV Stuff
[ -z $EM_SCRIPT ] && export EM_SCRIPT=$0
[ -z $EM_STORE ] && export EM_STORE=$HOME/.em
[ -d $EM_STORE ] || mkdir -p $EM_STORE

em() {
  # Special cases that don't require a platform to be set
  case $1 in
    'list'|'init')
      for platform in $(find $EM_STORE -maxdepth 1 -mindepth 1 -type d); do
        em ${platform##*/} $1
      done
      return 0
      ;;
  esac

  if [ -z $1 ] || [ -z $2 ]; then
    _em_command_help
    return
  fi

  declare -A EM_VARS
  _em_setup $1 $2; shift; shift;

  # First we try to run _em_{platform}_{cmd} then fall back to _em_{cmd}
  _em_maybe_fn "_em_command_${EM_VARS[platform]}_${EM_VARS[cmd]}" $@ || _em_maybe_fn "_em_command_${EM_VARS[cmd]}" $@

  if [ $? -gt 0 ]; then
    echo "Invalid command: ${EM_VARS[platform]} ${EM_VARS[cmd]}!"
    return 1
  fi
}

_em_command_help() {
  echo "Usage: em [platform] [command]"
  echo
  echo "Global Commands (no platform)"
  echo "  init                      Run init for all platforms found under ${EM_STORE}"
  echo "  list                      Run list for all platforms found under ${EM_STORE}"
  echo
  echo "Default Platform Commands"
  echo "  init                      Load the default profile if one is set"
  echo "  create <profile>          Create an profile for this platform"
  echo "  remove <profile>          Remove an profile from this platform"
  echo "  list                      List all profiles for this platform"
  echo "  use <profile>             Use the given profile for the current shell"
  echo "  unset                     Unset the current profile and remove all variables"
  echo "  do <profile> <command...> Run a command under the given profile"
  echo "  default <profile>         Show all available profiles"
}
_em_command_create() {
  if [ $# -lt 1 ]; then
    echo "Usage: em ${EM_VARS[platform]} create <profile>"
    return 1
  fi

  local profile=$1
  local store=${EM_VARS[store]}/${profile}

  if [ -f $store ]; then
    echo "${EM_VARS[platform]} profile ${profile} already exists!"
    return 1
  fi

  if ! _em_maybe_fn "_em_defaults_${EM_VARS[platform]}" $store; then
    echo "No defaults associated with ${EM_VARS[platform]}, creating a blank profile."
    touch $store
  fi

  _em_run_hook "create" $profile $store
  echo "Profile created! Edit ${store}, switch with em ${EM_VARS[platform]} use ${profile}"
}
_em_command_remove() {
  if [ $# -lt 1 ]; then
    echo "Usage: em ${EM_VARS[platform]} remove <profile>"
    return 1
  fi

  local profile=$1
  local store=${EM_VARS[store]}/${profile}

  if [ ! -f $store ]; then
    echo "${EM_VARS[platform]} profile ${profile} does not exist!"
    return 1
  fi

  if [ "${EM_VARS[profile]}" = "${profile}" ]; then
    em ${EM_VARS[platform]} unset
  fi

  rm -f $store
  _em_run_hook "remove" $profile $store
  echo "profile ${profile} removed!"
}
_em_command_use() {
  if [ $# -lt 1 ]; then
    echo "Usage: em ${EM_VARS[platform]} use <profile>"
    return 1
  fi

  local profile=$1
  local store=${EM_VARS[store]}/$profile

  if [ "$profile" = "${EM_VARS[profile]}" ]; then
    echo "Already on ${EM_VARS[platform]} ${profile}"
    return 0
  fi

  if [ ! -f $store ]; then
    echo "No profile named ${profile} for ${EM_VARS[platform]}"
    return 1
  fi

  em ${EM_VARS[platform]} unset

  source $store
  _em_run_hook "use" $profile $store

  eval "export EM_${EM_VARS[code]}_PROFILE=$profile"
  echo "Switched to ${EM_VARS[platform]} ${profile}"
}
_em_command_unset() {
  if [ -z ${EM_VARS[profile]} ]; then
    return 0
  fi

  local profile=${EM_VARS[profile]}
  local store=${EM_VARS[store]}/${EM_VARS[profile]}

  _em_debug "Unset profile ${profile}"

  if [ -f $store ]; then
    for key in $(awk -F '[#=\ ]' '$1 ~ /export/ {print $2}' $store); do
      _em_debug "unset ${key}"
      unset $key
    done
  fi

  _em_run_hook "unset" $profile $store
  eval "unset EM_${EM_VARS[code]}_PROFILE"
}
_em_command_do() {
  if [ $# -lt 1 ]; then
    echo "Usage: em ${EM_VARS[platform]} do <profile> <command...>"
    return 1
  fi

  local profile=$1
  local store=${EM_VARS[store]}/$profile
  shift
  local command=$*

  if [ ! -f $store ]; then
    echo "No profile named ${profile} for ${EM_VARS[platform]}"
    return 1
  fi

  _em_run_hook "do" $profile $store
  $SHELL -l -c "source ${EM_SCRIPT}; em ${EM_VARS[platform]} use ${profile}; ${command}"
}
_em_command_init() {
  if [ -z ${EM_VARS[profile]} ]; then
    if [ ! -z ${EM_VARS[default]} ]; then
      em ${EM_VARS[platform]} use ${EM_VARS[default]}
    fi
  fi
}
_em_command_default() {
  if [ $# -lt 1 ]; then
    echo "Usage: em ${EM_VARS[platform]} default <profile>"
    return 1
  fi

  local profile=$1
  local store=${EM_VARS[store]}/$profile

  if [ ! -f $store ]; then
    echo "No profile named ${profile} for ${EM_VARS[platform]}"
    return 1
  fi

  echo ${profile} > ${EM_VARS[default_file]}
  echo "Default profile for ${EM_VARS[platform]} set to ${profile}. Run em ${EM_VARS[platform]} init to switch."
}
_em_command_list() {
  echo "Available profiles for ${EM_VARS[platform]}"
  for profile in `ls ${EM_VARS[store]}`; do
    local ind=''
    if [ "${profile}" = "${EM_VARS[profile]}" ]; then
      ind='='
      [ "$profile" = "${EM_VARS[default]}" ] && ind+='*' || ind+='>'
    else
      ind=' '
      [ "$profile" = "${EM_VARS[default]}" ] && ind+='*' || ind+=' '
    fi

    echo "  ${ind} ${profile}"
  done
  echo
}

# Setup variables used by EM (with support for custom values set by the user)
_em_setup() {
  local platform=$1

  EM_VARS[platform]=$(echo $platform | tr '[:upper:]' '[:lower:]')
  EM_VARS[code]=$(echo $platform | tr '[:lower:]' '[:upper:]')
  EM_VARS[cmd]=$2

  _em_variable "store"        "EM_${EM_VARS[code]}_STORE"        "${EM_STORE}/${EM_VARS[platform]}"
  _em_variable "default_file" "EM_${EM_VARS[code]}_DEFAULT_FILE" "${EM_VARS[store]}/.default"
  _em_variable "default"      "EM_${EM_VARS[code]}_DEFAULT"
  _em_variable "profile"      "EM_${EM_VARS[code]}_PROFILE"
  _em_run_hook "set_variables"

  [ ! -d ${EM_VARS[store]} ] && mkdir -p ${EM_VARS[store]}
  [ -z ${EM_VARS[default]} ] && [ -f ${EM_VARS[default_file]} ] && EM_VARS[default]=`cat ${EM_VARS[default_file]}`
}

# Handle evaluating a variable variable and setting it to a default value
_em_variable() {
  eval "EM_VARS[$1]=\$$2"
  eval "[ -z \${EM_VARS[$1]} ] && EM_VARS[$1]=$3"
  _em_debug "EM_VARS[$1]=${EM_VARS[$1]}"
}

_em_func_exists() {
  declare -f -F $1 > /dev/null
  return $?
}
_em_maybe_fn() {
  if _em_func_exists $1; then
    _em_debug "run $@"
    eval "$@"
    return 0
  else
    return 1
  fi
}
_em_run_hook() {
  local hook=_em_hook_${EM_VARS[platform]}_$1
  shift
  _em_debug "run_hook ${hook}"
  _em_maybe_fn $hook $@
}

_em_debug() {
  [ ! -z $EM_DEBUG ] && [ $EM_DEBUG -eq 1 ] && echo "[EM ${EM_VARS[platform]} ${EM_VARS[cmd]}] $@"
}

###
# AWS Hooks
###

_em_defaults_aws() { # store
  cat > $1 <<EOC
export AWS_ACCESS_KEY=
export AWS_SECRET_KEY=
export AWS_ACCOUNT_ID=
export AWS_DEFAULT_REGION=
EOC
}

_em_hook_aws_set_variables() {
  [ -z $EC2_HOME ]                    && export EC2_HOME="/usr/share/ec2-api-tools"
  [ -z $AWS_AUTO_SCALING_HOME ]       && export AWS_AUTO_SCALING_HOME="/usr/share/as-api-tools"
  [ -z $AWS_CLOUDWATCH_HOME ]         && export AWS_CLOUDWATCH_HOME="/usr/share/cloudwatch-api-tools"
  [ -z $AWS_DEFAULT_CREDENTIAL_FILE ] && export AWS_DEFAULT_CREDENTIAL_FILE="$HOME/.ec2.creds"
}

_em_hook_aws_use() { # profile, store
  export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY
  export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_KEY

  [ -z $AWS_CREDENTIAL_FILE ] && export AWS_CREDENTIAL_FILE=$AWS_DEFAULT_CREDENTIAL_FILE
  cat > $AWS_CREDENTIAL_FILE <<EOC
AWSAccessKeyId=$AWS_ACCESS_KEY
AWSSecretKey=$AWS_SECRET_KEY
EOC
}

_em_hook_aws_unset() { # profile, store
  rm -f $AWS_CREDENTIAL_FILE

  unset AWS_ACCESS_KEY_ID
  unset AWS_SECRET_ACCESS_KEY
  unset AWS_CREDENTIAL_FILE
}

###
# Chef Hooks
###

_em_defaults_chef() { # store
  cat > $1 <<EOC
keypair_name =
hostname =
protocol = 'https'
port = 443
EOC
}

_em_command_chef_use() { # profile, store
  if [ $# -lt 1 ]; then
    echo "Usage: em ${EM_VARS[platform]} use <profile>"
    return 1
  fi

  local profile=$1
  local store=${EM_VARS[store]}/$profile

  if [ "$profile" = "${EM_VARS[profile]}" ]; then
    echo "Already on ${EM_VARS[platform]} ${profile}"
    return 0
  fi

  if [ ! -f $store ]; then
    echo "No profile named ${profile} for ${EM_VARS[platform]}"
    return 1
  fi

  em chef unset

  export CHEF_ENV_OVERRIDE='true'
  ln -sin $2 $HOME/.chef/overrides/knife-${profile}.rb

  eval "export EM_${EM_VARS[code]}_PROFILE=$profile"
  echo "Switched to ${EM_VARS[platform]} ${profile}"
}

_em_hook_chef_unset() { # profile, store
  rm -f $HOME/.chef/overrides/knife-${profile}.rb
  unset CHEF_ENV_OVERRIDE
}
