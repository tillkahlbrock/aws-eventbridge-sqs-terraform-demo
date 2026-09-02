// Der Producer besitzt das Schema seiner Events. Dieser Typ liegt deshalb im
// Service und nicht in einem geteilten Paket.
export const ORDERS_DOMAIN = "orders";
export const ORDER_SERVICE = "order-service";
export const ORDER_CREATED = "OrderCreated";
export const ORDER_CREATED_VERSION = 1;

export interface OrderCreatedPayload {
  orderId: string;
  totalCents: number;
}
