import pytest
import httpx

# Tell httpx to bind to either 0.0.0.0 or :: locally as a client,
# which allows us to effectively force either IPv6 or IPv4 transport
# in a crude manner
def make_client(*, user_agent: str, ipv6: bool) -> httpx.Client:
    transport = httpx.HTTPTransport(
        local_address="::" if ipv6 else "0.0.0.0"
    )

    return httpx.Client(
        transport=transport,
        follow_redirects=False,
        timeout=10.0,
        headers={
            "User-Agent": user_agent,
        },
    )

@pytest.fixture(scope="session")
def regular_client_ipv4():
    return make_client(
        user_agent="pytest-integration-tests",
        ipv6=False,
    )


@pytest.fixture(scope="session")
def regular_client_ipv6():
    return make_client(
        user_agent="pytest-integration-tests",
        ipv6=True,
    )

@pytest.fixture(scope="session")
def hsts_preload_client_ipv4():
    return make_client(
        user_agent="hstspreload-bot",
        ipv6=False,
    )


@pytest.fixture(scope="session")
def hsts_preload_client_ipv6():
    return make_client(
        user_agent="hstspreload-bot",
        ipv6=True,
    )
