Deface::Override.new(
  virtual_path: "spree/admin/shared/_order_summary",
  name: "manual-refund-button",
  insert_before: "#order_tab_summary",
  partial: "spree/adyen/manual_refund"
)
