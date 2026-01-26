# Auth Service Web Simulator

[![Portico Auth Example](https://img.shields.io/badge/Portico_Auth-Example-blue?style=for-the-badge&logo=dart)](https://dart.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](https://opensource.org/licenses/MIT)

<div style="text-align: center;">
<img src="../../assets/logo.svg" width="300" alt="Description of the image" />
</div>

This is an interactive simulation of the `portico_auth_service` ecosystem. It demonstrates how the various packages (`portico_auth_client`, `portico_auth_server_shelf`, `portico_auth_tokens`, etc.) work together to provide a secure authentication flow.

## How it Works

The simulator runs the **entire stack** inside your browser:

- **Server:** Running `AuthShelf` with in-memory storage.
- **Client:** Running `AuthClient` with a mock network adapter.
- **Network:** A virtual HTTP client that intercepts requests and routes them directly to the server logic.

## Key Features

1. **Virtual Network:** Watch real-time "HTTP" traffic between the client and server in the **Network Traffic** tab.
2. **Time Travel:** Advance time by minutes, hours, or days to see how tokens expire and how the `AuthClient` automatically handles refresh flows.
3. **State Inspection:**
    - **Server DB:** Inspect the server's internal state, including registered users and active refresh token chains.
    - **Client Storage:** See exactly what the client stores in its local storage (Access Tokens, Refresh Tokens) and decode the JWT claims.
4. **Security Scenarios:**
    - Try to access a **Protected API** while logged out.
    - Try to access a **Scoped API** (Admin only) to see role-based access control in action.
5. **Persistence:** Save the entire simulation state (including "databases") to your browser's LocalStorage and reload it later.

## Running the Simulator

To run this example locally:

```bash
cd examples/web_simulator
flutter run -d chrome
```

## Exploring the Code

- `lib/src/simulated_environment.dart`: The core logic that wires up the server and client.
- `lib/src/virtual_http_client.dart`: The adapter that simulates the network layer.
- `lib/src/views/`: The UI components for the app and the debugger.
