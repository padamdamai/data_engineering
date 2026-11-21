/*
  Frontend behavior for the order management page.

  This file has three main responsibilities:
  1. Load products and orders from the FastAPI backend.
  2. Track selected product quantities in the browser.
  3. Send order creation and status-update requests back to MongoDB through API.
*/

// state keeps frontend data in one predictable place.
// products: product catalog returned by GET /api/products.
// quantities: selected quantity for each product ID.
// orders: recent orders returned by GET /api/orders.
const state = { products: [], quantities: {}, orders: [] };

// The frontend uses the same transition map as the backend so the UI only
// offers valid next statuses. The backend still validates again for safety.
const statusTransitions = {
  PLACED: ["CONFIRMED", "CANCELLED"],
  CONFIRMED: ["PACKING", "CANCELLED"],
  PACKING: ["READY", "CANCELLED"],
  READY: ["DISPATCHED", "CANCELLED"],
  DISPATCHED: ["DELIVERED"],
  DELIVERED: [],
  CANCELLED: []
};

// Format numbers as Indian Rupee currency values for display.
const money = value => new Intl.NumberFormat("en-IN", {
  style: "currency",
  currency: "INR"
}).format(value);

// Escape text before placing it inside HTML strings.
// This prevents names or product values from being interpreted as HTML.
const escapeHtml = value => String(value).replace(/[&<>"']/g, character => ({
  "&": "&amp;",
  "<": "&lt;",
  ">": "&gt;",
  '"': "&quot;",
  "'": "&#039;"
}[character]));

// Common helper for calling the backend API.
// path is the URL, options can contain method and body for POST/PATCH requests.
async function api(path, options = {}) {
  const response = await fetch(path, {
    headers: { "Content-Type": "application/json" },
    ...options
  });

  // Some responses may not contain JSON, so parsing is protected with try/catch.
  let body = null;
  try {
    body = await response.json();
  } catch (_) {
    /* The response had no JSON body. */
  }

  // FastAPI sends validation and database errors as non-2xx responses.
  if (!response.ok) {
    throw new Error(body?.detail || "The request could not be completed.");
  }

  return body;
}

// Show a short message after important actions such as saving an order.
function showToast(message, error = false) {
  const toast = document.querySelector("#toast");
  toast.textContent = message;
  toast.className = `toast show${error ? " error" : ""}`;
  window.setTimeout(() => toast.classList.remove("show"), 3500);
}

// Check whether FastAPI can reach MongoDB Atlas.
async function checkConnection() {
  const element = document.querySelector("#connection-status");

  try {
    await api("/api/health");
    element.innerHTML = "<span></span>Atlas connected";
    element.className = "connection";
  } catch (_) {
    element.innerHTML = "<span></span>Atlas unavailable";
    element.className = "connection offline";
  }
}

// Load product catalog from MongoDB through the backend.
async function loadProducts() {
  const grid = document.querySelector("#product-grid");

  try {
    state.products = await api("/api/products");

    // Each card receives the product ID as data-product-id so click handlers
    // can identify which product quantity should change.
    grid.innerHTML = state.products.map(product => `
      <article class="product-card" data-product-id="${escapeHtml(product._id)}">
        <div>
          <h3>${escapeHtml(product.name)}</h3>
          <p class="product-meta">${escapeHtml(product.category)} · ${escapeHtml(product.unit)}</p>
          <span class="price">${money(product.price)}</span>
        </div>
        <div class="quantity">
          <button type="button" data-action="minus" aria-label="Remove one">−</button>
          <output>0</output>
          <button type="button" data-action="plus" aria-label="Add one">+</button>
        </div>
      </article>
    `).join("");
  } catch (error) {
    grid.innerHTML = `<div class="empty-state">${escapeHtml(error.message)}<br>Check the setup instructions in README.md.</div>`;
  }
}

// Update the selected quantity for one product and refresh the summary panel.
function changeQuantity(productId, change) {
  state.quantities[productId] = Math.max(
    0,
    Math.min(10, (state.quantities[productId] || 0) + change)
  );

  const card = document.querySelector(`[data-product-id="${productId}"]`);
  card.querySelector("output").textContent = state.quantities[productId];
  card.classList.toggle("selected", state.quantities[productId] > 0);
  renderSummary();
}

// Render the browser-side estimate. The backend calculates again when saving.
function renderSummary() {
  const selected = state.products.filter(product => state.quantities[product._id] > 0);
  const subtotal = selected.reduce(
    (sum, product) => sum + product.price * state.quantities[product._id],
    0
  );
  const delivery = subtotal === 0 ? 0 : subtotal >= 500 ? 0 : 40;

  document.querySelector("#summary-items").innerHTML = selected.length
    ? selected.map(product => `
        <div class="summary-line">
          <span>${state.quantities[product._id]} × ${escapeHtml(product.name)}</span>
          <strong>${money(product.price * state.quantities[product._id])}</strong>
        </div>
      `).join("")
    : '<p class="empty-summary">Select products to build the order.</p>';

  document.querySelector("#subtotal").textContent = money(subtotal);
  document.querySelector("#delivery-fee").textContent = delivery ? money(delivery) : subtotal ? "Free" : money(0);
  document.querySelector("#grand-total").textContent = money(subtotal + delivery);
}

// Create the order by sending form values to POST /api/orders.
async function submitOrder(event) {
  event.preventDefault();

  const items = Object.entries(state.quantities)
    .filter(([, quantity]) => quantity > 0)
    .map(([product_id, quantity]) => ({ product_id, quantity }));

  if (!items.length) {
    return showToast("Select at least one product.", true);
  }

  // The frontend sends only product_id and quantity for each item.
  // Product names and prices are intentionally looked up again by the backend.
  const payload = {
    customer: {
      name: document.querySelector("#customer-name").value,
      phone: document.querySelector("#customer-phone").value,
      email: document.querySelector("#customer-email").value
    },
    delivery_address: {
      address_line: document.querySelector("#address-line").value,
      city: document.querySelector("#city").value,
      postal_code: document.querySelector("#postal-code").value
    },
    items,
    payment_method: document.querySelector("#payment-method").value,
    delivery_slot: document.querySelector("#delivery-slot").value
  };

  const button = document.querySelector("#place-order");
  button.disabled = true;
  button.textContent = "Saving order...";

  try {
    const created = await api("/api/orders", {
      method: "POST",
      body: JSON.stringify(payload)
    });

    showToast(`Order ${created._id.slice(-8).toUpperCase()} was saved to MongoDB.`);

    // Reset the form and UI state after a successful insert.
    event.target.reset();
    state.quantities = {};
    renderSummary();
    document.querySelectorAll(".product-card").forEach(card => {
      card.classList.remove("selected");
      card.querySelector("output").textContent = "0";
    });

    await loadOrders();
    switchView("orders");
  } catch (error) {
    showToast(error.message, true);
  } finally {
    button.disabled = false;
    button.innerHTML = "Place order <span>→</span>";
  }
}

// Load recent orders and build the order-tracking cards.
async function loadOrders() {
  const list = document.querySelector("#orders-list");
  list.innerHTML = '<div class="loading">Loading orders...</div>';

  try {
    state.orders = await api("/api/orders");
    document.querySelector("#order-count").textContent = state.orders.length;

    if (!state.orders.length) {
      list.innerHTML = '<div class="empty-state">No orders have been placed yet.</div>';
      return;
    }

    list.innerHTML = state.orders.map(order => {
      const transitions = statusTransitions[order.status];
      const itemCount = order.items.reduce((total, item) => total + item.quantity, 0);

      // Build the status selector only when a next status is available.
      const control = transitions.length
        ? `<div class="status-control">
            <select aria-label="Next order status">
              ${transitions.map(value => `<option value="${escapeHtml(value)}">${escapeHtml(value.replaceAll("_", " "))}</option>`).join("")}
            </select>
            <button data-order-id="${escapeHtml(order._id)}">Update</button>
          </div>`
        : "<strong>Complete</strong>";

      return `
        <article class="order-card">
          <div class="order-top">
            <div>
              <span class="order-id">Order · ${escapeHtml(order._id.slice(-8))}</span>
              <h3>${escapeHtml(order.customer.name)}</h3>
              <p>${escapeHtml(new Date(order.created_at).toLocaleString("en-IN"))}</p>
            </div>
            <span class="status">${escapeHtml(order.status.replaceAll("_", " "))}</span>
          </div>
          <div class="order-details">
            <div>
              <span class="detail-label">Items</span>
              <strong>${itemCount} item${itemCount === 1 ? "" : "s"} · ${escapeHtml(order.items.map(item => item.name).join(", "))}</strong>
            </div>
            <div>
              <span class="detail-label">Delivery slot</span>
              <strong>${escapeHtml(order.delivery_slot)}</strong>
            </div>
            <div>
              <span class="detail-label">Order total</span>
              <strong>${money(order.pricing.grand_total)}</strong>
            </div>
            <div>${control}</div>
          </div>
        </article>
      `;
    }).join("");
  } catch (error) {
    list.innerHTML = `<div class="empty-state">${escapeHtml(error.message)}</div>`;
  }
}

// Send a status change to PATCH /api/orders/{order_id}/status.
async function updateStatus(button) {
  const select = button.previousElementSibling;
  button.disabled = true;

  try {
    await api(`/api/orders/${button.dataset.orderId}/status`, {
      method: "PATCH",
      body: JSON.stringify({ status: select.value })
    });
    showToast("Order status updated in MongoDB.");
    await loadOrders();
  } catch (error) {
    showToast(error.message, true);
    button.disabled = false;
  }
}

// Switch between the order form and recent orders screens.
function switchView(viewName) {
  document.querySelectorAll(".view").forEach(view => view.classList.remove("active"));
  document.querySelectorAll(".nav-link").forEach(button => {
    button.classList.toggle("active", button.dataset.view === viewName);
  });

  document.querySelector(`#${viewName}-view`).classList.add("active");

  if (viewName === "orders") {
    loadOrders();
  }

  window.scrollTo({ top: 0, behavior: "smooth" });
}

// Event delegation: one click listener handles plus/minus buttons for all
// product cards, including cards loaded after the page first renders.
document.querySelector("#product-grid").addEventListener("click", event => {
  const button = event.target.closest("button");
  if (!button) return;

  const productId = button.closest(".product-card").dataset.productId;
  const change = button.dataset.action === "plus" ? 1 : -1;
  changeQuantity(productId, change);
});

// Update buttons are generated dynamically, so the list listens for clicks.
document.querySelector("#orders-list").addEventListener("click", event => {
  const button = event.target.closest("button[data-order-id]");
  if (button) updateStatus(button);
});

// Register regular page-level event handlers.
document.querySelectorAll(".nav-link").forEach(button => {
  button.addEventListener("click", () => switchView(button.dataset.view));
});
document.querySelector("#order-form").addEventListener("submit", submitOrder);
document.querySelector("#refresh-orders").addEventListener("click", loadOrders);

// Initial page load: check database, load catalog, and load recent order count.
checkConnection();
loadProducts();
loadOrders();
