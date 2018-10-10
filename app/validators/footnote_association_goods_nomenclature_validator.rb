class FootnoteAssociationGoodsNomenclatureValidator < TradeTariffBackend::Validator
  validation :ME71,
    %(Footnotes with a footnote type for which the application type = "CN footnotes"
    cannot be associated with TARIC codes (codes with pos. 9-10 different from 00)),
    on: [:create, :update] do |record|
      record.footnote_type == "CN" && record.goods_nomenclature_item_id.last(2) == "00"
    end
end
