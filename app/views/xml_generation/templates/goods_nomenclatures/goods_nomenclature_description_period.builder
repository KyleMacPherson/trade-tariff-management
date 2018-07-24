xml.tag!("oub:goods.nomenclature.description.period") do |goods_nomenclature_description_period|
  xml_data_item_v2(goods_nomenclature_description_period, "goods.nomenclature.description.period.sid", self.goods_nomenclature_description_period_sid)
  xml_data_item_v2(goods_nomenclature_description_period, "goods.nomenclature.sid", self.goods_nomenclature_sid)
  xml_data_item_v2(goods_nomenclature_description_period, "goods.nomenclature.item.id", self.goods_nomenclature_item_id)
  xml_data_item_v2(goods_nomenclature_description_period, "productline.suffix", self.productline_suffix)
  xml_data_item_v2(goods_nomenclature_description_period, "validity.start.date", self.validity_start_date.strftime("%Y-%m-%d"))
  xml_data_item_v2(goods_nomenclature_description_period, "validity.end.date", self.validity_end_date.try(:strftime, "%Y-%m-%d"))
end
