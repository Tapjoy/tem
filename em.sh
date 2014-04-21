# EM is a utility for managing multiple environment profiles. It handles loading a default set of variables, ensures
# the litany of variables used by the tools are set and provides a mechanism for quickly switching between profiles.

# Common ENV Stuff
[ -z $EM_SCRIPT ] && export EM_SCRIPT=$0
[ -z $EM_STORE ] && export EM_STORE=$HOME/.em

# AWS ENV Stuff
[ -z $AAM_STORE ] && export AAM_STORE=$EM_STORE/aws
[ -d $AAM_STORE ] || mkdir -p $AAM_STORE
[ -z $AAM_DEFAULT_FILE ] && export AAM_DEFAULT_FILE=${AAM_STORE}/.default

[ -z $EC2_HOME ]              && export EC2_HOME="/usr/share/ec2-api-tools"
[ -z $AWS_AUTO_SCALING_HOME ] && export AWS_AUTO_SCALING_HOME="/usr/share/as-api-tools"
[ -z $AWS_CLOUDWATCH_HOME ]   && export AWS_CLOUDWATCH_HOME="/usr/share/cloudwatch-api-tools"
[ -z $AAM_DEFAULT_EC2_CREDS ] && export AAM_DEFAULT_EC2_CREDS="$HOME/.ec2.creds"

if [ -z $AAM_DEFAULT ]; then
  if [ -f $AAM_DEFAULT_FILE ]; then
    export AAM_DEFAULT=`cat ${AAM_DEFAULT_FILE}`
  fi
fi

# Chef ENV Stuff
[ -z $CEM_STORE ] && export CEM_STORE=$EM_STORE/chef
[ -d $CEM_STORE ] || mkdir -p $CEM_STORE
[ -z $CEM_DEFAULT_FILE ] && export CEM_DEFAULT_FILE=${CEM_STORE}/.default

if [ -z $CEM_DEFAULT ]; then
  if [ -f $CEM_DEFAULT_FILE ]; then
    export CEM_DEFAULT=`cat ${CEM_DEFAULT_FILE}`
  fi
fi

# Shell ENV stuff
[ -z $SEM_STORE ] && export SEM_STORE=$EM_STORE/env
[ -d $SEM_STORE ] || mkdir -p $SEM_STORE
[ -z $SEM_DEFAULT_FILE ] && export SEM_DEFAULT_FILE=${SEM_STORE}/.default

if [ -z $SEM_DEFAULT ]; then
  if [ -f $SEM_DEFAULT_FILE ]; then
    export SEM_DEFAULT=`cat ${SEM_DEFAULT_FILE}`
  fi
fi

em() {
  case $1 in
    'aws')
      shift
      aam $@
      ;;
    'chef')
      shift
      cem $@
      ;;
    'env')
      shift
      sem $@
      ;;
  esac
}
##############################################################################
# AAM is a utility for managing multiple AWS account credentials. It handles #
# loading a default set of credentials, ensures the litany of variables used #
# by the tools are set and provides a mechanism for quickly switching        #
# between accounts.                                                          #
##############################################################################

aam() {
  APPLICATION_NAME='AWS Account Manager'
  COMMAND='aam'
  if [ ! -z $1 ]; then
    cmd=$1
    shift
  else
    cmd='help'
  fi
  case $cmd in
    "help" )
      echo "${APPLICATION_NAME}"
      echo
      echo "Usage:"
      echo "  ${COMMAND} help                      Show this message"
      echo "  ${COMMAND} create <account>          Create a new AWS account"
      echo "  ${COMMAND} remove <account>          Remove AWS account"
      echo "  ${COMMAND} use <account>             Use the named AWS account"
      echo "  ${COMMAND} do <account> <command...> Run a command under the given account"
      echo "  ${COMMAND} default <account>         Set the default account"
      echo "  ${COMMAND} list                      Show all available accounts"
      echo
      ;;
    "create" )
      local account
      local store

      if [ $# -lt 1 ]; then
        echo "Usage: ${COMMAND} create <account>"
        return 1
      fi

      account=$1
      store=${AAM_STORE}/${account}
      shift

      if [ -f $store ]; then
        echo "AWS account named ${account} already exists!"
        return 1
      fi

      cat > $store <<EOC
export AWS_ACCESS_KEY=
export AWS_SECRET_KEY=
EOC

      echo "AWS account ${account} created! Edit ${store}, switch with ${COMMAND} use ${account}"
      ;;
    "remove")
      local account
      local store

      if [ $# -lt 1 ]; then
        echo "Usage: ${COMMAND} remove <account>"
        return 1
      fi

      account=$1
      store=${AAM_STORE}/${account}
      shift

      if [ -f $store ]; then
        rm $store
        return 0
      else
        echo "Chef profile ${account} does not exist at ${store}"
        return 1
      fi
      ;;
    "use" )
      local account
      local store

      if [ $# -lt 1 ]; then
        echo "Usage: ${COMMAND} use <account>"
        return 1
      fi

      account=$1
      shift

      if [ $account = 'default' ]; then
        if [ -z $AAM_DEFAULT ]; then
          echo "No default account has been configured. Set one with ${COMMAND} default <account>."
          return 1
        fi
        account=$AAM_DEFAULT
      fi

      store=${AAM_STORE}/${account}
      if [ ! -f $store ]; then
        echo "No account named ${account}"
        return 1
      fi

      export AAM_ACCOUNT=$account

      # Unset variables that may be set by the config
      [ -z $AWS_CREDENTIAL_FILE ]   || unset AWS_CREDENTIAL_FILE

      source $store

      [ -z $AWS_CREDENTIAL_FILE ] && export AWS_CREDENTIAL_FILE=$AAM_DEFAULT_EC2_CREDS
      export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY
      export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_KEY

      cat > $AWS_CREDENTIAL_FILE <<EOC
AWSAccessKeyId=$AWS_ACCESS_KEY
AWSSecretKey=$AWS_SECRET_KEY
EOC

      echo "Switched to account ${account}"
      ;;
    "do" )
      local account

      if [ $# -lt 1 ]; then
        echo "Usage: aam do <account> <command...>"
        return 1
      fi

      account=$1
      store=${AAM_STORE}/${account}
      shift
      command=$*

      if [ ! -f $store ]; then
        echo "No account named ${account}"
        return 1
      fi

      $SHELL -l -c "source ${EM_SCRIPT}; aam use ${account}; ${command}"
      ;;
    "default" )
      local account

      if [ $# -lt 1 ]; then
        echo "Usage: aam default <account>"
        return 1
      fi

      account=$1
      store=${AAM_STORE}/${account}
      shift

      if [ ! -f $store ]; then
        echo "No account named ${account}"
        return 1
      fi

      echo $account > $AAM_DEFAULT_FILE
      echo "Default account set to ${account}"
      ;;
    "list" )
      echo
      echo "Available accounts"
      for account in `ls $AAM_STORE`; do
        local ind=''
        if [ "$account" = "$AAM_ACCOUNT" ]; then
          ind='='
          [ "$account" = "$AAM_DEFAULT" ] && ind+='*' || ind+='>'
        else
          ind=' '
          [ "$account" = "$AAM_DEFAULT" ] && ind+='*' || ind+=' '
        fi

        echo "${ind} ${account}"
      done
      echo
      echo '# => - current'
      echo '# =* - current & default'
      echo '#  * - default'
      ;;
  esac
}

############################################################################
# CEM is a utility for managing multiple chef environments. It handles     #
# loading a default set of variables, ensures the litany of variables      #
# used by the tools are set and provides a mechanism for quickly switching #
# between profiles.                                                        #
############################################################################
cem() {
  APPLICATION_NAME='Chef Environment Manager'
  COMMAND='cem'
  if [ ! -z $1 ]; then
    cmd=$1
    shift
  else
    cmd='help'
  fi
  case $cmd in
    "help" )
      echo "${APPLICATION_NAME}"
      echo
      echo "Usage:"
      echo "  ${COMMAND} help                      Show this message"
      echo "  ${COMMAND} create <account>          Create a new AWS account"
      echo "  ${COMMAND} remove <account>          Remove AWS account"
      echo "  ${COMMAND} use <account>             Use the named AWS account"
      echo "  ${COMMAND} do <account> <command...> Run a command under the given account"
      echo "  ${COMMAND} default <account>         Set the default account"
      echo "  ${COMMAND} list                      Show all available accounts"
      ;;
    "create" )
      local account
      local store

      if [ $# -lt 1 ]; then
        echo "Usage: ${COMMAND} create <account>"
        return 1
      fi

      account=$1
      store=${CEM_STORE}/${account}
      shift

      if [ -f $store ]; then
        echo "Chef profile named ${account} already exists!"
        return 1
      fi

       cat > $store <<EOC
keypair_name = 
hostname = 
protocol = 'https'
port = 443
EOC

      echo "Chef profile ${account} created! Edit ${store}, switch with ${COMMAND} use ${account}"
      ;;
    "remove")
      local account
      local store

      if [ $# -lt 1 ]; then
        echo "Usage: ${COMMAND} remove <account>"
        return 1
      fi

      account=$1
      store=${CEM_STORE}/${account}
      shift

      if [ -f $store ]; then
        rm $store
        return 0
      else
        echo "Chef profile ${account} does not exist at ${store}"
        return 1
      fi
      ;;
    "use" )
      local account
      local store

      if [ $# -lt 1 ]; then
        echo "Usage: ${COMMAND} use <account>"
        return 1
      fi

      account=$1
      shift

      if [ $account = 'default' ]; then
        if [ -z $CEM_DEFAULT ]; then
          echo "No default account has been configured. Set one with aam default <account>."
          return 1
        fi
        account=$CEM_DEFAULT
      fi

      store=${CEM_STORE}/${account}
      if [ ! -f $store ]; then
        echo "No account named ${account}"
        return 1
      fi

      export CEM_ACCOUNT=$account
      export CHEF_ENV_OVERRIDE='true'

      rm -f $HOME/.chef/overrides/*
      ln -sin $store $HOME/.chef/overrides/knife-${account}.rb

      echo "Switched to account ${account}"
      ;;
     "do" )
       local account

       if [ $# -lt 1 ]; then
         echo "Usage: ${COMMAND} do <account> <command...>"
         return 1
       fi

       account=$1
       store=${CEM_STORE}/${account}
       shift
       command=$*

       if [ ! -f $store ]; then
         echo "No account named ${account}"
         return 1
       fi

       $SHELL -l -c "source ${EM_SCRIPT}; ${COMMAND} use ${account}; ${command}"
       ;;
    "default" )
      local account

      if [ $# -lt 1 ]; then
        echo "Usage: ${COMMAND} default <account>"
        return 1
      fi

      account=$1
      store=${CEM_STORE}/${account}
      shift

      if [ ! -f $store ]; then
        echo "No account named ${account}"
        return 1
      fi

      echo $account > $CEM_DEFAULT_FILE
      echo "Default account set to ${account}"
      ;;
    "list" )
      echo
      echo "Available accounts"
      for account in $(ls $CEM_STORE); do
        local ind=''
        if [ "$account" = "$CEM_ACCOUNT" ]; then
          ind='='
          [ "$account" = "$CEM_DEFAULT" ] && ind+='*' || ind+='>'
        else
          ind=' '
          [ "$account" = "$CEM_DEFAULT" ] && ind+='*' || ind+=' '
        fi

        echo "${ind} ${account}"
      done
      echo
      echo '# => - current'
      echo '# =* - current & default'
      echo '#  * - default'
      ;;
  esac
}
###############################################################################
# SEM is a utility for managing multiple environments. It handles loading a   #
# default set of variables, ensures the litany of variables used by the tools #
# are set and provides a mechanism for quickly switching between profiles.    #
############################################################################### 
sem(){
  APPLICATION_NAME='Shell Environment Manager'
  COMMAND='sem'
  if [ ! -z $1 ]; then
    cmd=$1
    shift
  else
    cmd='help'
  fi
  case $cmd in
    "help" )
      echo "${APPLICATION_NAME}"
      echo
      echo "Usage:"
      echo "  ${COMMAND} help                      Show this message"
      echo "  ${COMMAND} create <account>          Create a new AWS account"
      echo "  ${COMMAND} remove <account>          Remove AWS account"
      echo "  ${COMMAND} use <account>             Use the named AWS account"
      echo "  ${COMMAND} do <account> <command...> Run a command under the given account"
      echo "  ${COMMAND} default <account>         Set the default account"
      echo "  ${COMMAND} list                      Show all available accounts"
      ;;
    "create" )
      local account
      local store

      if [ $# -lt 1 ]; then
        echo "Usage: ${COMMAND} create <account>"
        return 1
      fi

      account=$1
      store=${SEM_STORE}/${account}
      shift

      if [ -f $store ]; then
        echo "Profile named ${account} already exists!"
        return 1
      fi

      touch $store

      echo "Profile ${account} created! Edit ${store}, switch with ${COMMAND} use ${account}"
      ;;
    "remove")
      local account
      local store

      if [ $# -lt 1 ]; then
        echo "Usage: ${COMMAND} remove <account>"
        return 1
      fi

      account=$1
      store=${SEM_STORE}/${account}
      shift

      if [ -f $store ]; then
        rm $store
        return 0
      else
        echo "Profile ${account} does not exist at ${store}"
        return 1
      fi
      ;;
    "use" )
      local account
      local store

      if [ $# -lt 1 ]; then
        echo "Usage: ${COMMAND} use <account>"
        return 1
      fi

      account=$1
      shift

      if [ $account = 'default' ]; then
        if [ -z $SEM_DEFAULT ]; then
          echo "No default account has been configured. Set one with aam default <account>."
          return 1
        fi
        account=$SEM_DEFAULT
      fi

      store=${SEM_STORE}/${account}
      if [ ! -f $store ]; then
        echo "No account named ${account}"
        return 1
      fi

      old_store=${SEM_STORE}/${SEM_ACCOUNT}
      export SEM_ACCOUNT=$account
      for key in $(awk -F'[#=\ ]' '$1 ~ /export/ {print $2}' ${old_store}); do
        unset $key
      done
      source ${store}
      echo "Switched to account ${account}"
      ;;
    "do" )
      local account

      if [ $# -lt 1 ]; then
        echo "Usage: ${COMMAND} do <account> <command...>"
        return 1
      fi

      account=$1
      store=${SEM_STORE}/${account}
      shift
      command=$*

      if [ ! -f $store ]; then
        echo "No account named ${account}"
        return 1
      fi

      $SHELL -l -c "source ${EM_SCRIPT}; ${COMMAND} use ${account}; ${command}"
      ;;
    "default" )
      local account

      if [ $# -lt 1 ]; then
        echo "Usage: ${COMMAND} default <account>"
        return 1
      fi

      account=$1
      store=${SEM_STORE}/${account}
      shift

      if [ ! -f $store ]; then
        echo "No account named ${account}"
        return 1
      fi

      echo $account > $SEM_DEFAULT_FILE
      echo "Default account set to ${account}"
      ;;
    "list" )
      echo
      echo "Available accounts"
      for account in $(ls $SEM_STORE); do
        local ind=''
        if [ "$account" = "$SEM_ACCOUNT" ]; then
          ind='='
          [ "$account" = "$SEM_DEFAULT" ] && ind+='*' || ind+='>'
        else
          ind=' '
          [ "$account" = "$SEM_DEFAULT" ] && ind+='*' || ind+=' '
        fi

        echo "${ind} ${account}"
      done
      echo
      echo '# => - current'
      echo '# =* - current & default'
      echo '#  * - default'
      ;;
  esac
}
if [ -z $AAM_ACCOUNT ]; then
  aam use default > /dev/null
fi

if [ -z $CEM_ACCOUNT ]; then
  cem use default > /dev/null
fi

if [ -z $SEM_ACCOUNT ]; then
  sem use default > /dev/null
fi