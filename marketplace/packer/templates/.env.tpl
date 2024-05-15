### Added with Packer don't replace ###
cd /home/${project_user}/${project_name}

%{ for key, value in project_env_variables }export ${key}=${value}
%{ endfor ~}
