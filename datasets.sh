#!/bin/bash

set -e

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "script must be sourced - not for direct invocation" && exit 1
fi

sonardatasets=(
    rdns_v2:rdns.json.gz
    fdns_v2:fdns_a.json.gz
    fdns_v2:fdns_mx.json.gz
    fdns_v2:fdns_ns.json.gz
    fdns_v2:fdns_txt.json.gz
    fdns_v2:fdns_any.json.gz
    fdns_v2:fdns_aaaa.json.gz
    fdns_v2:fdns_cname.json.gz
    fdns_v2:fdns_txt_mx_dmarc.json.gz
    fdns_v2:fdns_txt_mx_mta-sts.json.gz
)

ssldatasets=(
    ssl:https_get_8002_names.gz
    ssl:https_get_8002_hosts.gz
    ssl:https_get_8002_endpoints.gz
    ssl:https_get_8002_certs.gz
    ssl:https_get_5001_names.gz
    ssl:https_get_5001_hosts.gz
    ssl:https_get_5001_endpoints.gz
    ssl:https_get_5001_certs.gz
    ssl:https_get_16993_names.gz
    ssl:https_get_16993_hosts.gz
    moressl:pop3s_995_names.gz
    moressl:pop3s_995_hosts.gz
    moressl:pop3s_995_endpoints.gz
    moressl:pop3s_995_certs.gz
    moressl:pop3_starttls_110_names.gz
    moressl:pop3_starttls_110_hosts.gz
    moressl:pop3_starttls_110_endpoints.gz
    moressl:pop3_starttls_110_certs.gz
    moressl:smtp_starttls_587_names.gz
    moressl:smtp_starttls_587_hosts.gz
)
