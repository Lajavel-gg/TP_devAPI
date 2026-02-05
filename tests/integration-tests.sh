#!/bin/bash
# =============================================================================
# Script de Tests d'Integration - API SIREN
# Genere un rapport JSON et HTML avec les resultats des tests
# =============================================================================

set -e

# Configuration
BASE_URL="${BASE_URL:-https://caddy:8443}"
CLIENT_ID="${CLIENT_ID:-mysql-api-client}"
CLIENT_SECRET="${CLIENT_SECRET:-mysql_api_secret}"
REPORT_DIR="${REPORT_DIR:-/reports}"
CURL_OPTS="-sk --connect-timeout 10 --max-time 30"

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Compteurs
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Resultats JSON
declare -a TEST_RESULTS=()

# =============================================================================
# Fonctions utilitaires
# =============================================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

log_error() {
    echo -e "${RED}[FAIL]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Fonction de test generique
run_test() {
    local test_name="$1"
    local test_description="$2"
    local test_command="$3"
    local expected_status="${4:-200}"
    local validate_json="${5:-true}"

    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    local start_time=$(date +%s%N)

    echo ""
    log_info "Test #$TESTS_TOTAL: $test_name"
    echo "  Description: $test_description"

    # Executer le test
    local http_code
    local response
    local temp_file=$(mktemp)

    http_code=$(eval "$test_command" -w "%{http_code}" -o "$temp_file" 2>/dev/null) || http_code="000"
    response=$(cat "$temp_file" 2>/dev/null || echo "")
    rm -f "$temp_file"

    local end_time=$(date +%s%N)
    local duration=$(( (end_time - start_time) / 1000000 )) # en ms

    local status="PASSED"
    local error_message=""

    # Verifier le code HTTP
    if [[ "$http_code" != "$expected_status" ]]; then
        status="FAILED"
        error_message="Expected HTTP $expected_status, got $http_code"
    fi

    # Verifier si JSON valide (si demande)
    if [[ "$status" == "PASSED" && "$validate_json" == "true" && -n "$response" ]]; then
        if ! echo "$response" | jq . > /dev/null 2>&1; then
            status="FAILED"
            error_message="Response is not valid JSON"
        fi
    fi

    # Mettre a jour les compteurs
    if [[ "$status" == "PASSED" ]]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        log_success "$test_name (${duration}ms)"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        log_error "$test_name - $error_message"
    fi

    # Ajouter au rapport JSON
    local json_result=$(jq -n \
        --arg name "$test_name" \
        --arg description "$test_description" \
        --arg status "$status" \
        --arg error "$error_message" \
        --arg http_code "$http_code" \
        --arg duration_ms "$duration" \
        --arg response "${response:0:500}" \
        '{
            name: $name,
            description: $description,
            status: $status,
            error: $error,
            http_code: $http_code,
            duration_ms: ($duration_ms | tonumber),
            response_preview: $response
        }')

    TEST_RESULTS+=("$json_result")
}

# =============================================================================
# Attendre que les services soient prets
# =============================================================================

wait_for_services() {
    log_info "Attente des services..."

    local max_attempts=60
    local attempt=0

    # Attendre OAuth2
    while [[ $attempt -lt $max_attempts ]]; do
        if curl $CURL_OPTS "$BASE_URL/health" > /dev/null 2>&1; then
            log_success "Caddy proxy ready"
            break
        fi
        attempt=$((attempt + 1))
        echo -n "."
        sleep 2
    done

    if [[ $attempt -eq $max_attempts ]]; then
        log_error "Services not ready after ${max_attempts} attempts"
        exit 1
    fi

    # Petit delai supplementaire pour stabilisation
    sleep 5
}

# =============================================================================
# TESTS OAUTH2
# =============================================================================

test_oauth2() {
    echo ""
    echo "=============================================="
    echo "        TESTS OAUTH2 SERVER"
    echo "=============================================="

    # Test 1: Health check OAuth2
    run_test \
        "oauth2_health" \
        "Verification de la sante du serveur OAuth2" \
        "curl $CURL_OPTS '$BASE_URL/oauth/health'" \
        "200" \
        "true"

    # Test 2: Obtenir un token valide
    run_test \
        "oauth2_get_token" \
        "Obtention d'un token avec client_credentials" \
        "curl $CURL_OPTS -X POST '$BASE_URL/oauth/token' -d 'grant_type=client_credentials&client_id=$CLIENT_ID&client_secret=$CLIENT_SECRET'" \
        "200" \
        "true"

    # Recuperer le token pour les tests suivants
    TOKEN=$(curl $CURL_OPTS -X POST "$BASE_URL/oauth/token" \
        -d "grant_type=client_credentials&client_id=$CLIENT_ID&client_secret=$CLIENT_SECRET" 2>/dev/null \
        | jq -r '.access_token' 2>/dev/null || echo "")

    if [[ -z "$TOKEN" || "$TOKEN" == "null" ]]; then
        log_error "Impossible d'obtenir un token - tests API annules"
        TESTS_SKIPPED=$((TESTS_SKIPPED + 10))
        return 1
    fi

    log_success "Token obtenu: ${TOKEN:0:20}..."
    export TOKEN

    # Test 3: Token avec mauvais credentials
    run_test \
        "oauth2_invalid_credentials" \
        "Rejet de credentials invalides" \
        "curl $CURL_OPTS -X POST '$BASE_URL/oauth/token' -d 'grant_type=client_credentials&client_id=fake&client_secret=fake'" \
        "401" \
        "true"

    # Test 4: Introspection du token
    run_test \
        "oauth2_introspect" \
        "Introspection d'un token valide" \
        "curl $CURL_OPTS -X POST '$BASE_URL/oauth/introspect' -d 'token=$TOKEN'" \
        "200" \
        "true"

    return 0
}

# =============================================================================
# TESTS API ENTREPRISES (MySQL)
# =============================================================================

test_mysql_api() {
    echo ""
    echo "=============================================="
    echo "        TESTS API ENTREPRISES (MySQL)"
    echo "=============================================="

    if [[ -z "$TOKEN" ]]; then
        log_warn "Token non disponible - tests MySQL API ignores"
        TESTS_SKIPPED=$((TESTS_SKIPPED + 5))
        return 1
    fi

    # Test 5: Health check MySQL API
    run_test \
        "mysql_api_health" \
        "Verification de la sante de l'API MySQL" \
        "curl $CURL_OPTS '$BASE_URL/api/entreprises/health'" \
        "200" \
        "true"

    # Test 6: Recherche par SIREN
    run_test \
        "mysql_api_siren" \
        "Recherche entreprise par SIREN (552032534 - DANONE)" \
        "curl $CURL_OPTS -H 'Authorization: Bearer $TOKEN' '$BASE_URL/api/entreprises/siren/552032534'" \
        "200" \
        "true"

    # Test 7: Recherche par nom
    run_test \
        "mysql_api_search_name" \
        "Recherche entreprises par nom (danone)" \
        "curl $CURL_OPTS -H 'Authorization: Bearer $TOKEN' '$BASE_URL/api/entreprises/search?nom=danone'" \
        "200" \
        "true"

    # Test 8: Recherche par activite
    run_test \
        "mysql_api_activite" \
        "Recherche entreprises par code activite (62.01Z)" \
        "curl $CURL_OPTS -H 'Authorization: Bearer $TOKEN' '$BASE_URL/api/entreprises/activite/62.01Z'" \
        "200" \
        "true"

    # Test 9: Pagination
    run_test \
        "mysql_api_pagination" \
        "Test de la pagination (page 1, 10 elements)" \
        "curl $CURL_OPTS -H 'Authorization: Bearer $TOKEN' '$BASE_URL/api/entreprises/search?nom=sas&page=1&pageSize=10'" \
        "200" \
        "true"

    # Test 10: Requete sans token (doit echouer)
    run_test \
        "mysql_api_no_auth" \
        "Rejet des requetes sans authentification" \
        "curl $CURL_OPTS '$BASE_URL/api/entreprises/siren/552032534'" \
        "401" \
        "true"

    # Test 11: SIREN invalide
    run_test \
        "mysql_api_invalid_siren" \
        "Gestion d'un SIREN inexistant" \
        "curl $CURL_OPTS -H 'Authorization: Bearer $TOKEN' '$BASE_URL/api/entreprises/siren/000000000'" \
        "404" \
        "true"
}

# =============================================================================
# TESTS API STATISTIQUES (Spark)
# =============================================================================

test_spark_api() {
    echo ""
    echo "=============================================="
    echo "        TESTS API STATISTIQUES (Spark)"
    echo "=============================================="

    if [[ -z "$TOKEN" ]]; then
        log_warn "Token non disponible - tests Spark API ignores"
        TESTS_SKIPPED=$((TESTS_SKIPPED + 4))
        return 1
    fi

    # Test 12: Health check Spark API
    run_test \
        "spark_api_health" \
        "Verification de la sante de l'API Spark" \
        "curl $CURL_OPTS '$BASE_URL/api/stats/health'" \
        "200" \
        "true"

    # Test 13: Top activites
    run_test \
        "spark_api_top_activites" \
        "Recuperation des top 10 activites" \
        "curl $CURL_OPTS -H 'Authorization: Bearer $TOKEN' '$BASE_URL/api/stats/top-activites?limit=10'" \
        "200" \
        "true"

    # Test 14: Bottom activites
    run_test \
        "spark_api_bottom_activites" \
        "Recuperation des 10 activites les moins representees" \
        "curl $CURL_OPTS -H 'Authorization: Bearer $TOKEN' '$BASE_URL/api/stats/bottom-activites?limit=10'" \
        "200" \
        "true"

    # Test 15: Stats par pattern
    run_test \
        "spark_api_filter" \
        "Filtrage des activites par pattern (62)" \
        "curl $CURL_OPTS -H 'Authorization: Bearer $TOKEN' '$BASE_URL/api/stats/activites/filter/62'" \
        "200" \
        "true"

    # Test 16: Requete sans token (doit echouer)
    run_test \
        "spark_api_no_auth" \
        "Rejet des requetes sans authentification" \
        "curl $CURL_OPTS '$BASE_URL/api/stats/top-activites'" \
        "401" \
        "true"
}

# =============================================================================
# TESTS SWAGGER/DOCUMENTATION
# =============================================================================

test_swagger() {
    echo ""
    echo "=============================================="
    echo "        TESTS DOCUMENTATION SWAGGER"
    echo "=============================================="

    # Test 17: Swagger OAuth2
    run_test \
        "swagger_oauth" \
        "Acces documentation Swagger OAuth2" \
        "curl $CURL_OPTS '$BASE_URL/docs/oauth'" \
        "200" \
        "false"

    # Test 18: Swagger MySQL API
    run_test \
        "swagger_mysql" \
        "Acces documentation Swagger MySQL API" \
        "curl $CURL_OPTS '$BASE_URL/docs/mysql'" \
        "200" \
        "false"

    # Test 19: Swagger Spark API
    run_test \
        "swagger_spark" \
        "Acces documentation Swagger Spark API" \
        "curl $CURL_OPTS '$BASE_URL/docs/spark'" \
        "200" \
        "false"
}

# =============================================================================
# GENERATION DU RAPPORT
# =============================================================================

generate_report() {
    echo ""
    echo "=============================================="
    echo "        GENERATION DU RAPPORT"
    echo "=============================================="

    mkdir -p "$REPORT_DIR"

    local timestamp=$(date -Iseconds)
    local duration_total=$(($(date +%s) - START_TIME))

    # Construire le JSON des resultats
    local results_json="["
    for i in "${!TEST_RESULTS[@]}"; do
        if [[ $i -gt 0 ]]; then
            results_json+=","
        fi
        results_json+="${TEST_RESULTS[$i]}"
    done
    results_json+="]"

    # Rapport JSON
    local report_json=$(jq -n \
        --arg timestamp "$timestamp" \
        --arg duration "$duration_total" \
        --arg total "$TESTS_TOTAL" \
        --arg passed "$TESTS_PASSED" \
        --arg failed "$TESTS_FAILED" \
        --arg skipped "$TESTS_SKIPPED" \
        --arg base_url "$BASE_URL" \
        --argjson results "$results_json" \
        '{
            metadata: {
                timestamp: $timestamp,
                duration_seconds: ($duration | tonumber),
                base_url: $base_url,
                version: "1.0.0"
            },
            summary: {
                total: ($total | tonumber),
                passed: ($passed | tonumber),
                failed: ($failed | tonumber),
                skipped: ($skipped | tonumber),
                success_rate: (if ($total | tonumber) > 0 then ((($passed | tonumber) / ($total | tonumber)) * 100 | floor) else 0 end)
            },
            tests: $results
        }')

    echo "$report_json" > "$REPORT_DIR/test-report.json"
    log_success "Rapport JSON genere: $REPORT_DIR/test-report.json"

    # Rapport HTML
    generate_html_report "$report_json"

    # Afficher le resume
    echo ""
    echo "=============================================="
    echo "              RESUME DES TESTS"
    echo "=============================================="
    echo ""
    echo "  Total:    $TESTS_TOTAL"
    echo -e "  ${GREEN}Reussis:  $TESTS_PASSED${NC}"
    echo -e "  ${RED}Echoues:  $TESTS_FAILED${NC}"
    echo -e "  ${YELLOW}Ignores:  $TESTS_SKIPPED${NC}"
    echo ""
    local success_rate=0
    if [[ $TESTS_TOTAL -gt 0 ]]; then
        success_rate=$((TESTS_PASSED * 100 / TESTS_TOTAL))
    fi
    echo "  Taux de reussite: ${success_rate}%"
    echo "  Duree totale: ${duration_total}s"
    echo ""

    # Code de sortie
    if [[ $TESTS_FAILED -gt 0 ]]; then
        return 1
    fi
    return 0
}

generate_html_report() {
    local report_json="$1"
    local html_file="$REPORT_DIR/test-report.html"

    local timestamp=$(echo "$report_json" | jq -r '.metadata.timestamp')
    local total=$(echo "$report_json" | jq -r '.summary.total')
    local passed=$(echo "$report_json" | jq -r '.summary.passed')
    local failed=$(echo "$report_json" | jq -r '.summary.failed')
    local skipped=$(echo "$report_json" | jq -r '.summary.skipped')
    local success_rate=$(echo "$report_json" | jq -r '.summary.success_rate')

    cat > "$html_file" << 'HTMLEOF'
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Rapport de Tests - API SIREN</title>
    <style>
        :root {
            --color-pass: #22c55e;
            --color-fail: #ef4444;
            --color-skip: #f59e0b;
            --color-bg: #0f172a;
            --color-card: #1e293b;
            --color-text: #e2e8f0;
            --color-border: #334155;
        }
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body {
            font-family: 'Segoe UI', system-ui, sans-serif;
            background: var(--color-bg);
            color: var(--color-text);
            line-height: 1.6;
            padding: 2rem;
        }
        .container { max-width: 1200px; margin: 0 auto; }
        header {
            text-align: center;
            margin-bottom: 2rem;
            padding-bottom: 2rem;
            border-bottom: 1px solid var(--color-border);
        }
        h1 { font-size: 2.5rem; margin-bottom: 0.5rem; }
        .timestamp { color: #94a3b8; font-size: 0.9rem; }
        .summary {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 1rem;
            margin-bottom: 2rem;
        }
        .stat-card {
            background: var(--color-card);
            border-radius: 12px;
            padding: 1.5rem;
            text-align: center;
            border: 1px solid var(--color-border);
        }
        .stat-value {
            font-size: 3rem;
            font-weight: bold;
            margin-bottom: 0.5rem;
        }
        .stat-label { color: #94a3b8; text-transform: uppercase; font-size: 0.8rem; letter-spacing: 1px; }
        .stat-pass .stat-value { color: var(--color-pass); }
        .stat-fail .stat-value { color: var(--color-fail); }
        .stat-skip .stat-value { color: var(--color-skip); }
        .progress-bar {
            height: 8px;
            background: var(--color-border);
            border-radius: 4px;
            overflow: hidden;
            margin: 1rem 0;
        }
        .progress-fill {
            height: 100%;
            background: linear-gradient(90deg, var(--color-pass), #16a34a);
            transition: width 0.5s ease;
        }
        .tests-section { margin-top: 2rem; }
        .section-title {
            font-size: 1.5rem;
            margin-bottom: 1rem;
            padding-bottom: 0.5rem;
            border-bottom: 2px solid var(--color-border);
        }
        .test-card {
            background: var(--color-card);
            border-radius: 8px;
            padding: 1rem 1.5rem;
            margin-bottom: 0.75rem;
            border-left: 4px solid var(--color-border);
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        .test-card.passed { border-left-color: var(--color-pass); }
        .test-card.failed { border-left-color: var(--color-fail); }
        .test-card.skipped { border-left-color: var(--color-skip); }
        .test-name { font-weight: 600; }
        .test-description { color: #94a3b8; font-size: 0.9rem; margin-top: 0.25rem; }
        .test-meta { text-align: right; }
        .test-status {
            padding: 0.25rem 0.75rem;
            border-radius: 20px;
            font-size: 0.8rem;
            font-weight: 600;
            text-transform: uppercase;
        }
        .test-status.passed { background: rgba(34, 197, 94, 0.2); color: var(--color-pass); }
        .test-status.failed { background: rgba(239, 68, 68, 0.2); color: var(--color-fail); }
        .test-duration { color: #64748b; font-size: 0.85rem; margin-top: 0.25rem; }
        .error-message {
            color: var(--color-fail);
            font-size: 0.85rem;
            margin-top: 0.5rem;
            font-family: monospace;
        }
        footer {
            text-align: center;
            margin-top: 3rem;
            padding-top: 2rem;
            border-top: 1px solid var(--color-border);
            color: #64748b;
        }
        @media print {
            body { background: white; color: black; }
            .stat-card, .test-card { border: 1px solid #ddd; }
        }
    </style>
</head>
<body>
    <div class="container">
        <header>
            <h1>Rapport de Tests API SIREN</h1>
            <p class="timestamp">TIMESTAMP_PLACEHOLDER</p>
        </header>

        <div class="summary">
            <div class="stat-card">
                <div class="stat-value">TOTAL_PLACEHOLDER</div>
                <div class="stat-label">Tests Total</div>
            </div>
            <div class="stat-card stat-pass">
                <div class="stat-value">PASSED_PLACEHOLDER</div>
                <div class="stat-label">Reussis</div>
            </div>
            <div class="stat-card stat-fail">
                <div class="stat-value">FAILED_PLACEHOLDER</div>
                <div class="stat-label">Echoues</div>
            </div>
            <div class="stat-card stat-skip">
                <div class="stat-value">SKIPPED_PLACEHOLDER</div>
                <div class="stat-label">Ignores</div>
            </div>
        </div>

        <div class="progress-bar">
            <div class="progress-fill" style="width: SUCCESS_RATE_PLACEHOLDER%;"></div>
        </div>
        <p style="text-align: center; margin-bottom: 2rem;">
            Taux de reussite: <strong>SUCCESS_RATE_PLACEHOLDER%</strong>
        </p>

        <div class="tests-section">
            <h2 class="section-title">Details des Tests</h2>
            TESTS_PLACEHOLDER
        </div>

        <footer>
            <p>Genere automatiquement par le pipeline CI/CD Drone</p>
            <p>API SIREN - Architecture Microservices</p>
        </footer>
    </div>
</body>
</html>
HTMLEOF

    # Remplacer les placeholders
    sed -i "s/TIMESTAMP_PLACEHOLDER/$timestamp/g" "$html_file"
    sed -i "s/TOTAL_PLACEHOLDER/$total/g" "$html_file"
    sed -i "s/PASSED_PLACEHOLDER/$passed/g" "$html_file"
    sed -i "s/FAILED_PLACEHOLDER/$failed/g" "$html_file"
    sed -i "s/SKIPPED_PLACEHOLDER/$skipped/g" "$html_file"
    sed -i "s/SUCCESS_RATE_PLACEHOLDER/$success_rate/g" "$html_file"

    # Generer les cartes de tests
    local tests_html=""
    while IFS= read -r test; do
        local name=$(echo "$test" | jq -r '.name')
        local desc=$(echo "$test" | jq -r '.description')
        local status=$(echo "$test" | jq -r '.status')
        local duration=$(echo "$test" | jq -r '.duration_ms')
        local error=$(echo "$test" | jq -r '.error')

        local status_lower=$(echo "$status" | tr '[:upper:]' '[:lower:]')

        tests_html+="<div class=\"test-card $status_lower\">"
        tests_html+="<div class=\"test-info\">"
        tests_html+="<div class=\"test-name\">$name</div>"
        tests_html+="<div class=\"test-description\">$desc</div>"
        if [[ "$error" != "" && "$error" != "null" ]]; then
            tests_html+="<div class=\"error-message\">$error</div>"
        fi
        tests_html+="</div>"
        tests_html+="<div class=\"test-meta\">"
        tests_html+="<div class=\"test-status $status_lower\">$status</div>"
        tests_html+="<div class=\"test-duration\">${duration}ms</div>"
        tests_html+="</div>"
        tests_html+="</div>"
    done < <(echo "$report_json" | jq -c '.tests[]')

    # Echapper les caracteres speciaux pour sed
    tests_html=$(echo "$tests_html" | sed 's/[&/\]/\\&/g')
    sed -i "s|TESTS_PLACEHOLDER|$tests_html|g" "$html_file"

    log_success "Rapport HTML genere: $html_file"
}

# =============================================================================
# MAIN
# =============================================================================

main() {
    echo ""
    echo "=============================================="
    echo "    TESTS D'INTEGRATION - API SIREN"
    echo "    $(date)"
    echo "=============================================="

    START_TIME=$(date +%s)

    # Attendre les services
    wait_for_services

    # Executer les tests
    test_oauth2 || true
    test_mysql_api || true
    test_spark_api || true
    test_swagger || true

    # Generer le rapport
    generate_report
    exit_code=$?

    exit $exit_code
}

main "$@"
