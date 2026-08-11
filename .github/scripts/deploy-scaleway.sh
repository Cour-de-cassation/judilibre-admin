#!/usr/bin/env bash
# Déploie judilibre-admin sur un cluster public Scaleway.
#
#   usage : deploy-scaleway.sh <groupe-de-inventaire>
#
# Le groupe désigne le cluster : scw_dev_par1, scw_prod_par1, scw_prod_par2.
# Tout le reste vient de ansible/group_vars/<groupe>/ et de group_vars/scw/.
set -euo pipefail

if [ "$#" -lt 1 ]; then
    echo "usage : $0 <groupe-de-inventaire>" >&2
    exit 1
fi
groupe="$1"

if [ -z "${IMAGE:-}" ]; then
    echo "❌ IMAGE est vide — impossible de savoir quoi déployer." >&2
    exit 1
fi

# group_vars/all/vault.yml est chiffré et se charge pour tout hôte, y compris
# ceux de cet inventaire : le mot de passe du vault est donc requis même quand
# le playbook ne lit aucun secret.
if [ -z "${ANSIBLE_VAULT_PASSWORD:-}" ]; then
    echo "❌ ANSIBLE_VAULT_PASSWORD est vide — le secret manque au dépôt." >&2
    exit 1
fi

fichier_vault="$(mktemp)"
trap 'rm -f "${fichier_vault}"' EXIT
printf '%s' "${ANSIBLE_VAULT_PASSWORD}" > "${fichier_vault}"
chmod 600 "${fichier_vault}"

echo "▶ ${groupe} — image ${IMAGE}"

ANSIBLE_FORCE_COLOR=true \
ansible-playbook \
    -i ansible/inventory/scw.yml \
    --limit "${groupe}" \
    --vault-password-file "${fichier_vault}" \
    -e "app_image=${IMAGE}" \
    ansible/deploy_app_public.yml
