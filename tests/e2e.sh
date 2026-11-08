#!/usr/bin/env bash
# Tests de bout en bout de la plateforme déployée par Argo CD
set -euo pipefail
pass() { echo "✅ $*"; }
fail() { echo "❌ $*"; exit 1; }

echo "1/4 Attente : applications Argo CD Synced + Healthy"
for i in $(seq 1 90); do
  status=$(kubectl -n argocd get applications -o json \
    | jq -r '.items[] | "\(.metadata.name) \(.status.sync.status) \(.status.health.status)"')
  echo "$status" | column -t; echo "---"
  # l'application racine peut rester OutOfSync (champs gérés par Argo CD) : on vérifie les applications filles
  children=$(echo "$status" | grep -v "^root " || true)
  if [ "$(echo "$children" | wc -l)" -ge 8 ] && ! echo "$children" | grep -vq "Synced Healthy"; then
    pass "$(echo "$children" | wc -l) applications Synced/Healthy"; break
  fi
  [ "$i" -eq 90 ] && fail "applications non convergées"
  sleep 10
done

echo "2/4 Application exposée en HTTPS via ingress-nginx + certificat cert-manager"
kubectl -n demo wait certificate/demo-app-tls --for=condition=Ready --timeout=180s
kubectl -n ingress-nginx port-forward svc/ingress-nginx-controller 8443:443 >/dev/null 2>&1 &
sleep 5
curl -skf --resolve demo.local:8443:127.0.0.1 https://demo.local:8443/ | jq -e '.hostname' \
  && pass "podinfo répond en HTTPS" || fail "ingress HTTPS"

echo "3/4 Prometheus scrape l'application (ServiceMonitor)"
kubectl -n monitoring port-forward svc/kps-prometheus 9090:9090 >/dev/null 2>&1 &
sleep 5
for i in $(seq 1 24); do
  up=$(curl -s 'http://127.0.0.1:9090/api/v1/query' --data-urlencode 'query=sum(up{namespace="demo"})' | jq -r '.data.result[0].value[1] // "0"')
  [ "$up" -ge 1 ] 2>/dev/null && { pass "Prometheus : $up cible(s) demo UP"; break; }
  [ "$i" -eq 24 ] && fail "cible Prometheus absente"
  sleep 10
done

echo "4/4 Kyverno bloque une image :latest dans le namespace demo"
kubectl wait clusterpolicy --all --for=condition=Ready --timeout=120s
if kubectl -n demo run interdit --image=nginx:latest 2>err.txt; then
  fail "le pod :latest a été accepté"
else
  grep -q "disallow-latest-tag" err.txt && pass "pod :latest refusé par Kyverno" || { cat err.txt; fail "refus inattendu"; }
fi
echo "Tous les tests sont passés."
