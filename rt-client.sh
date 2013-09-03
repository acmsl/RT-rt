#!/bin/bash dry-wit
# Copyright 2013-today Automated Computing Machinery S.L.
# Distributed under the terms of the GNU General Public License v3

function usage() {
cat <<EOF
$SCRIPT_NAME [-v[v]] [-q|--quiet] init remote-url
$SCRIPT_NAME [-v[v]] [-q|--quiet] commit
$SCRIPT_NAME [-v[v]] [-q|--quiet] push
$SCRIPT_NAME [-h|--help]
(c) 2013-today Automated Computing Machinery S.L.
    Distributed under the terms of the GNU General Public License v3
 
Client script for RT.

- Init command: When setting up a new project, it prepares the project
to be able to commit and push changes remotely.
- Commit command: Commits any change to the internal repository.
- Push command: Pushes accumulated changes to the remote repository.
 
Where:
  * remote-url: The remote repository.
EOF
}
 
# Requirements
function checkRequirements() {
  checkReq git GIT_NOT_INSTALLED;
}
 
# Environment
function defineEnv() {
  export GIT_BASEDIR_DEFAULT="$HOME/.RT.git.d";
  export GIT_BASEDIR_DESCRIPTION="The git folder";
  if    [ "${GIT_BASEDIR+1}" != "1" ] \
     || [ "x${GIT_BASEDIR}" == "x" ]; then
    export GIT_BASEDIR="${GIT_BASEDIR_DEFAULT}";
  fi

  export GIT_DIR_DEFAULT="${GIT_BASEDIR}/$(basename $PWD)";
  export GIT_DIR_DESCRIPION="Where the actual git repository is located";
  if   [ "${GIT_DIR+1}" != "1" ] \
     || [ "x${GIT_DIR}" == "x" ]; then
    export GIT_DIR="${GIT_DIR_DEFAULT}";
  fi

  ENV_VARIABLES=(\
    GIT_BASEDIR \
    GIT_DIR \
  );
 
  export ENV_VARIABLES;
}

# Error messages
function defineErrors() {
  export INVALID_OPTION="Unrecognized option";
  export GIT_NOT_INSTALLED="git not installed";
  export COMMAND_IS_MANDATORY="command is mandatory";
  export INVALID_COMMAND="Invalid command";
  export REMOTE_REPOSITORY_IS_MANDATORY="remote repository url is mandatory";
  export CANNOT_SETUP_GIT_REPOSITORY="Cannot setup internal git repository";
  export CANNOT_ADD_FILES="Cannot add existing files to RT repository";
  export CANNOT_COMMIT_CHANGES="Cannot commit changes";
  export CANNOT_PUSH_CHANGES="Cannot push changes";

  ERROR_MESSAGES=(\
    INVALID_OPTION \
    GIT_NOT_INSTALLED \
    COMMAND_IS_MANDATORY \
    INVALID_COMMAND \
    REMOTE_REPOSITORY_IS_MANDATORY \
    CANNOT_SETUP_GIT_REPOSITORY \
    CANNOT_ADD_FILES \
    CANNOT_COMMIT_CHANGES \
    CANNOT_PUSH_CHANGES \
  );

  export ERROR_MESSAGES;
}
 
# Checking input
function checkInput() {
 
  local _flags=$(extractFlags $@);
  local _flagCount;
  local _currentCount;
  logInfo -n "Checking input";

  # Flags
  for _flag in ${_flags}; do
    _flagCount=$((_flagCount+1));
    case ${_flag} in
      -h | --help | -v | -vv | -q)
         shift;
         ;;
      *) exitWithErrorCode INVALID_OPTION ${_flag};
         ;;
    esac
  done
 
  # Parameters
  if [ "x${COMMAND}" == "x" ]; then
    COMMAND="$1";
    shift;
  fi

  if [ "x${COMMAND}" == "x" ]; then
    logInfoResult FAILURE "fail";
    exitWithErrorCode COMMAND_IS_MANDATORY;
  fi
 
  if [ "${COMMAND}" == "init" ]; then
    if [ "x${REMOTE_REPOS}" == "x" ]; then
      REMOTE_REPOS="$1";
      shift;
    fi

    if [ "x${REMOTE_REPOS}" == "x" ]; then
      logInfoResult FAILURE "fail";
      exitWithErrorCode REMOTE_REPOSITORY_IS_MANDATORY;
    fi
  fi
  logInfoResult SUCCESS "valid";
}

function main() {

  case "${COMMAND}" in
    "init")
      git_init "${REMOTE_REPOS}";
      ;;
    "commit")
      git_commit;
      ;;
    "push")
      git_push;
      ;;
    *) exitWithErrorCode INVALID_COMMAND;
      ;;
  esac
}

function git_init() {
  local _remoteRepos="${1}";
  local rescode=0;

  logInfo -n "Initializing git";

  mkdir -p "${GIT_DIR}" 2>&1 > /dev/null;
  rescode=$?;

  if [ $rescode -eq 0 ]; then

    git --git-dir "${GIT_DIR}" --work-tree . init "${_remoteRepos}" 2>&1 > /dev/null
    rescode=$?;

    if [ $rescode -eq 0 ]; then

      git --git-dir "${GIT_DIR}" --work-tree . remote add origin "${_remoteRepos}" 2>&1 > /dev/null
      rescode=$?;

      if [ $rescode -eq 0 ]; then
        git --git-dir "${GIT_DIR}" --work-tree . pull origin master 2>&1 3>&1 > /dev/null
        rescode=$?;
        if [ $rescode -eq 0 ]; then
          logInfoResult SUCCESS "done";
        else
          logInfoResult FAILURE "failed";
          exitWithErrorCode CANNOT_SETUP_GIT_REPOSITORY;
        fi
      else
        logInfoResult FAILURE "failed";
        exitWithErrorCode CANNOT_SETUP_GIT_REPOSITORY;
      fi
    else
      rm -rf "${GIT_DIR}" 2>&1 > /dev/null
      logInfoResult FAILURE "failed";
      exitWithErrorCode CANNOT_SETUP_GIT_REPOSITORY;
    fi
  else
    logInfoResult FAILURE "failed";
    exitWithErrorCode CANNOT_SETUP_GIT_REPOSITORY;
  fi

  git_add_files
}

function git_add_files() {
  local rescode=0;

  logInfo -n "Adding files";

  find . -type f -exec file {} \; 2>&1 | grep -v target | grep text | grep -v -e '~$' | cut -d':' -f 1 | awk -vG="${GIT_DIR}" '{printf("git --git-dir %s --work-tree . add --ignore-errors %s 2>&1 > /dev/null\n", G, $0);}' | sh 2>&1 > /dev/null
  rescode=$?;
  if [ $rescode -eq 0 ]; then
    logInfoResult SUCCESS "done";
  else
    logInfoResult FAILURE "failed";
    exitWithErrorCode CANNOT_ADD_FILES;
  fi
}

function git_commit() {
  local rescode=0;

  logInfo -n "Commiting changes";

  git --git-dir "${GIT_DIR}" --work-tree . status | tail -n 1 | grep "nothing" | grep "commit" 2>&1 > /dev/null
  rescode=$?;
  if [ $rescode -eq 0 ]; then
    logInfoResult SUCCESS "done";
  else
    git --git-dir "${GIT_DIR}" --work-tree . commit -a -m"$(date '+%Y%m%d%H%M')" 2>&1 > /dev/null
    rescode=$?;
    if [ $rescode -eq 0 ]; then
      logInfoResult SUCCESS "done";
    else
      logInfoResult FAILURE "failed";
      exitWithErrorCode CANNOT_COMMIT_CHANGES;
    fi
  fi  
}

function git_push() {
  local rescode=0;

  logInfo -n "Pushing changes";

  git --git-dir "${GIT_DIR}" --work-tree . push origin master 2>&1 > /dev/null
  rescode=$?;
  if [ $rescode -eq 0 ]; then
    logInfoResult SUCCESS "done";
  else
    logInfoResult FAILURE "failed";
    exitWithErrorCode CANNOT_PUSH_CHANGES;
  fi  
}
