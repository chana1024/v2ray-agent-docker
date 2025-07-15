
# V2Ray Agent (Docker)

This project provides a Dockerized version of the v2ray-agent, allowing you to easily deploy a V2Ray (or other compatible core) server in a containerized environment.

## Quick Start

1.  **Clone the repository:**

    ```bash
    git clone https://github.com/your_github_repo/v2ray-agent.git
    cd v2ray-agent/docker
    ```

2.  **Configure `docker-compose.yml`:**

    Open `docker-compose.yml` and set the `DOMAIN` and `UUID` environment variables:

    ```yaml
    environment:
      - DOMAIN=your_domain.com  # Replace with your domain
      - UUID=your_uuid          # Replace with your UUID
    ```

3.  **Start the container:**

    ```bash
    docker-compose up -d
    ```

4.  **View logs:**

    ```bash
    docker-compose logs -f
    ```

## Environment Variables

*   `DOMAIN`: (Required) Your domain name.
*   `UUID`: (Required) Your VLESS UUID.
*   `CORE_TYPE`: (Optional) The core to use. Supported values: `xray`, `sing-box`. Defaults to `xray`.
*   `PROTOCOLS`: (Optional) A comma-separated list of protocols to enable. See the supported protocols section below. Defaults to `VLESS_vision_reality`.
*   `CDN_ADDRESS`: (Optional) A CDN address to use for subscription links. Defaults to your `DOMAIN`.

## Supported Protocols

### sing-box

*   `VLESS_vision_reality`
*   `VLESS_ws_tls`

### xray

*   `VLESS_vision_reality` (coming soon)

## Subscription

Your subscription link will be available at:

```
https://your_domain.com/subscribe/your_uuid
```
