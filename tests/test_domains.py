import re
from urllib.parse import urlparse, urlunparse

# Helper Functions
def normalize_url(url: str) -> str:
    """
    Normalize URLs by stripping trailing slashes as we don't really care
    about them for the purpose of our redirect testing down below
    """
    parsed = urlparse(url)
    
    # Normalize root "/" vs "/" with trailing slash
    path = parsed.path
    if path == "/":
        path = ""  # treat "/" and "" as equivalent
    else:
        path = path.rstrip("/")
    
    normalized = urlunparse(
        (parsed.scheme.lower(), parsed.netloc.lower(), path, "", "", "")
    )
    return normalized

def assert_redirect(response, expected_location, expected_status=(301, 302, 308)):
    """
    Assert the response is a redirect to the expected location,
    ignoring trailing slashes.
    """
    assert response.status_code in expected_status, (
        f"Expected redirect status {expected_status}, got {response.status_code}"
    )

    actual = normalize_url(response.headers["location"])
    expected = normalize_url(expected_location)

    assert actual == expected, f"Redirect mismatch: got {actual}, expected {expected}"

# Redirect Tests (IPv6)
def test_https_alexhaydock_co_uk_redirects_to_blog_over_ipv6(regular_client_ipv6):
    response = regular_client_ipv6.get("https://alexhaydock.co.uk")
    assert_redirect(response, "https://blog.infected.systems")

def test_https_alexhaydock_com_redirects_to_blog_over_ipv6(regular_client_ipv6):
    response = regular_client_ipv6.get("https://alexhaydock.com")
    assert_redirect(response, "https://blog.infected.systems")

def test_http_infected_systems_redirects_to_blog_over_ipv6(regular_client_ipv6):
    response = regular_client_ipv6.get("http://infected.systems")
    assert_redirect(response, "http://blog.infected.systems")

def test_https_infected_systems_redirects_to_blog_over_ipv6(regular_client_ipv6):
    response = regular_client_ipv6.get("https://infected.systems")
    assert_redirect(response, "https://blog.infected.systems")

def test_apex_domain_redirects_to_https_when_client_is_hsts_preload_bot_over_ipv6(hsts_preload_client_ipv6):
    response = hsts_preload_client_ipv6.get("http://infected.systems")
    assert_redirect(response, "https://infected.systems")

# Redirect Tests (IPv4)
def test_https_alexhaydock_co_uk_redirects_to_blog_over_ipv4(regular_client_ipv4):
    response = regular_client_ipv4.get("https://alexhaydock.co.uk")
    assert_redirect(response, "https://blog.infected.systems")

def test_https_alexhaydock_com_redirects_to_blog_over_ipv4(regular_client_ipv4):
    response = regular_client_ipv4.get("https://alexhaydock.com")
    assert_redirect(response, "https://blog.infected.systems")

def test_http_infected_systems_redirects_to_blog_over_ipv4(regular_client_ipv4):
    response = regular_client_ipv4.get("http://infected.systems")
    assert_redirect(response, "http://blog.infected.systems")

def test_https_infected_systems_redirects_to_blog_over_ipv4(regular_client_ipv4):
    response = regular_client_ipv4.get("https://infected.systems")
    assert_redirect(response, "https://blog.infected.systems")

def test_apex_domain_redirects_to_https_when_client_is_hsts_preload_bot_over_ipv4(hsts_preload_client_ipv4):
    response = hsts_preload_client_ipv4.get("http://infected.systems")
    assert_redirect(response, "https://infected.systems")

# Header Tests (IPv6)
def test_blog_serves_http3_alt_svc_header_over_https_over_ipv6(regular_client_ipv6):
    response = regular_client_ipv6.get("https://blog.infected.systems")
    alt_svc = response.headers.get("alt-svc")
    assert alt_svc is not None
    assert "h3" in alt_svc.lower()

def test_blog_serves_strong_content_security_policy_over_ipv6(regular_client_ipv6):
    response = regular_client_ipv6.get("https://blog.infected.systems")
    csp = response.headers.get("content-security-policy")
    assert csp is not None
    assert "script-src 'none'" in csp.lower()

def test_apex_domain_serves_hsts_preload_header_over_https_over_ipv6(regular_client_ipv6):
    response = regular_client_ipv6.get("https://infected.systems")
    hsts = response.headers.get("strict-transport-security")
    assert hsts is not None

    assert "includesubdomains" in hsts.lower()
    assert "preload" in hsts.lower()

    max_age_match = re.search(r"max-age=(\d+)", hsts)
    assert max_age_match is not None
    assert int(max_age_match.group(1)) >= 31536000

def test_blog_serves_onion_location_header_over_https_over_ipv6(regular_client_ipv6):
    response = regular_client_ipv6.get("https://blog.infected.systems")
    onion_location = response.headers.get("onion-location")
    assert onion_location is not None
    assert onion_location.startswith("http")

# Header Tests (IPv4)
def test_blog_serves_http3_alt_svc_header_over_https_over_ipv4(regular_client_ipv4):
    response = regular_client_ipv4.get("https://blog.infected.systems")
    alt_svc = response.headers.get("alt-svc")
    assert alt_svc is not None
    assert "h3" in alt_svc.lower()

def test_blog_serves_strong_content_security_policy_over_ipv4(regular_client_ipv4):
    response = regular_client_ipv4.get("https://blog.infected.systems")
    csp = response.headers.get("content-security-policy")
    assert csp is not None
    assert "script-src 'none'" in csp.lower()

def test_apex_domain_serves_hsts_preload_header_over_https_over_ipv4(regular_client_ipv4):
    response = regular_client_ipv4.get("https://infected.systems")
    hsts = response.headers.get("strict-transport-security")
    assert hsts is not None

    assert "includesubdomains" in hsts.lower()
    assert "preload" in hsts.lower()

    max_age_match = re.search(r"max-age=(\d+)", hsts)
    assert max_age_match is not None
    assert int(max_age_match.group(1)) >= 31536000

def test_blog_serves_onion_location_header_over_https_over_ipv4(regular_client_ipv4):
    response = regular_client_ipv4.get("https://blog.infected.systems")
    onion_location = response.headers.get("onion-location")
    assert onion_location is not None
    assert onion_location.startswith("http")

# Content Tests (IPv6)
def test_blog_contains_hacker_webring_personal_link_over_ipv6(regular_client_ipv6):
    response = regular_client_ipv6.get("https://blog.infected.systems")
    assert response.status_code == 200
    assert '<a href="//ring.acab.dev/rand/aJyOZIVRZ0">' in response.text

# Content Tests (IPv4)
def test_blog_contains_hacker_webring_personal_link_over_ipv4(regular_client_ipv4):
    response = regular_client_ipv4.get("https://blog.infected.systems")
    assert response.status_code == 200
    assert '<a href="//ring.acab.dev/rand/aJyOZIVRZ0">' in response.text
