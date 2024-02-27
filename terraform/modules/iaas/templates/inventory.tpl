[all]
${connection_strings_master}
${connection_strings_nodes}
${public_ip_address_bastion}

[all:vars]
${additional_variables_for_all}

[bastion]
${public_ip_address_bastion}

[bastion:vars]
${additional_variables_for_bastion}

[kube_control_plane]
${list_master}

%{ for group,nodes in workgroup ~}
[${group}]
%{ for node in nodes ~}
${node}
%{ endfor ~}
%{ endfor ~}

%{ for group,resource in workgroup_nodes ~}
[${group}:vars]
%{ if length(resource.labels) > 0 }node_labels={${join(",",resource.labels)}}%{ endif }
%{ if length(resource.taints) > 0 }node_taints=[${join(",",resource.taints)}]%{ endif }
%{ endfor ~}

[kube_node]
${list_node}

[etcd]
${list_etcd}

[calico_rr]

[k8s_cluster:children]
kube_node
kube_control_plane
calico_rr

[k8s_cluster:vars]
${cluster_name}
${elb_api_fqdn}
