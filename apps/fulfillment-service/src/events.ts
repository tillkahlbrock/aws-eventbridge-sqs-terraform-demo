// Tolerant Reader: der Consumer deklariert nur die Felder, die er liest. Das
// vollständige Schema von OrderCreated besitzt der Producer. Deshalb gibt es
// hier keinen Import aus dem order-service.
export interface OrderCreatedRead {
  orderId: string;
}

export const SUPPORTED_ORDER_CREATED_VERSION = 1;

// Das Folge-Event gehört diesem Service, deshalb eine eigene Domain.
export const FULFILLMENT_DOMAIN = "fulfillment";
export const FULFILLMENT_SERVICE = "fulfillment-service";
export const SHIPMENT_PREPARED = "ShipmentPrepared";
export const SHIPMENT_PREPARED_VERSION = 1;

export interface ShipmentPreparedPayload {
  orderId: string;
  shipmentId: string;
}
