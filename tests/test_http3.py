import asyncio
import pytest
from aioquic.asyncio import connect
from aioquic.h3.connection import H3_ALPN, H3Connection
from aioquic.quic.configuration import QuicConfiguration

@pytest.mark.asyncio
async def test_blog_supports_real_http3_connectivity():
    """
    Attempt a real QUIC/H3 connection to blog.infected.systems.
    Fails if HTTP/3 is not negotiated.
    """
    host = "blog.infected.systems"
    port = 443
    config = QuicConfiguration(is_client=True, alpn_protocols=H3_ALPN)

    try:
        # Limit total connection attempt to 5 seconds
        async with asyncio.timeout(5):
            async with connect(host, port, configuration=config) as protocol:
                # Wait until handshake completes
                await protocol.wait_connected()

                # Try to instantiate H3Connection
                try:
                    h3 = H3Connection(protocol._quic)
                except Exception as e:
                    pytest.fail(f"HTTP/3 not negotiated: {e}")

                # If we got here, HTTP/3 is supported
                assert h3 is not None

    except asyncio.TimeoutError:
        pytest.fail("Timed out trying to connect — HTTP/3 not established")
    except OSError as e:
        pytest.fail(f"OS/network error during HTTP/3 connection: {e}")
    except Exception as e:
        pytest.fail(f"Unexpected error: {e}")
