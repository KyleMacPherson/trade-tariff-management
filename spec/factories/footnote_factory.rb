FactoryGirl.define do
  sequence(:footnote_sid) { |n| n }

  factory :footnote do
    transient do
      valid_at { Date.today.ago(2.years) }
      valid_to { nil }
      goods_nomenclature_sid { generate(:goods_nomenclature_sid) }
    end

    footnote_id      { Forgery(:basic).text(exactly: 3) }
    footnote_type_id { Forgery(:basic).text(exactly: 2) }
    validity_start_date     { Date.today.ago(2.years).localtime }
    validity_end_date       { nil }

    after(:build) { |ftn, _evaluator|
      FactoryGirl.create(:footnote_type, footnote_type_id: ftn.footnote_type_id,
                                         validity_start_date: ftn.validity_start_date - 1.day)
      ftn_desc_period = FactoryGirl.create(:footnote_description_period, footnote_type_id: ftn.footnote_type_id,
                                                       footnote_id: ftn.footnote_id,
                                                       validity_start_date: ftn.validity_start_date)
      FactoryGirl.create(:footnote_description, footnote_type_id: ftn.footnote_type_id,
                                                footnote_id: ftn.footnote_id,
                                                footnote_description_period_sid: ftn_desc_period.footnote_description_period_sid)
    }

    trait :with_gono_association do
      after(:create) { |ftn, evaluator|
        FactoryGirl.create(:footnote_association_goods_nomenclature, goods_nomenclature_sid: evaluator.goods_nomenclature_sid,
                                                                     footnote_id: ftn.footnote_id,
                                                                     footnote_type: ftn.footnote_type_id,
                                                                     validity_start_date: evaluator.valid_at,
                                                                     validity_end_date: evaluator.valid_to)
      }
    end

    trait :national do
      national { true }
    end

    trait :non_national do
      national { false }
    end

    trait :xml do
      validity_end_date { Date.today.ago(1.years) }
    end
  end

  factory :footnote_description_period do
    footnote_description_period_sid { generate(:footnote_sid) }
    footnote_id                     { Forgery(:basic).text(exactly: 3) }
    footnote_type_id                { Forgery(:basic).text(exactly: 2) }
    validity_start_date             { Date.today.ago(2.years) }
    validity_end_date               { nil }

    trait :xml do
      validity_end_date { Date.today.ago(1.years) }
    end
  end

  factory :footnote_description do
    transient do
      valid_at { Date.today.ago(2.years) }
      valid_to { nil }
    end

    footnote_description_period_sid { generate(:footnote_sid) }
    footnote_id                     { Forgery(:basic).text(exactly: 3) }
    footnote_type_id                { Forgery(:basic).text(exactly: 2) }
    description                     { Forgery(:lorem_ipsum).sentence }

    trait :with_period do
      after(:create) { |ftn_description, evaluator|
        FactoryGirl.create(:footnote_description_period, footnote_description_period_sid: ftn_description.footnote_description_period_sid,
                                                                footnote_id: ftn_description.footnote_id,
                                                                footnote_type_id: ftn_description.footnote_type_id,
                                                                validity_start_date: evaluator.valid_at,
                                                                validity_end_date: evaluator.valid_to)
      }
    end

    trait :xml do
      language_id                   { "EN" }
    end
  end

  factory :footnote_association_goods_nomenclature do
    goods_nomenclature_sid          { generate(:goods_nomenclature_sid) }
    footnote_id                     { Forgery(:basic).text(exactly: 3) }
    footnote_type                   { Forgery(:basic).text(exactly: 2) }
    validity_start_date             { Date.today.ago(3.years) }
    validity_end_date               { nil }

    trait :xml do
      goods_nomenclature_item_id    { "0406909200" }
      productline_suffix            { "80" }
      validity_end_date             { Date.today.ago(1.years) }
    end
  end

  factory :footnote_association_ern do
    export_refund_nomenclature_sid  { generate(:export_refund_nomenclature_sid) }
    footnote_id                     { Forgery(:basic).text(exactly: 3) }
    footnote_type                   { Forgery(:basic).text(exactly: 2) }
    validity_start_date             { Date.today.ago(2.years) }
    validity_end_date               { nil }

    trait :xml do
      goods_nomenclature_item_id    { "0406909200" }
      additional_code_type          { "9" }
      export_refund_code            { "500" }
      productline_suffix            { "80" }
      validity_end_date             { Date.today.ago(1.years) }
    end
  end

  factory :footnote_association_measure do
    measure_sid                     { generate(:measure_sid) }
    footnote_id                     { Forgery(:basic).text(exactly: 3) }
    footnote_type_id                { Forgery(:basic).text(exactly: 2) }
  end

  factory :footnote_association_additional_code do
    additional_code_sid             { generate(:additional_code_sid) }
    footnote_id                     { Forgery(:basic).text(exactly: 3) }
    footnote_type_id                { Forgery(:basic).text(exactly: 2) }
    validity_start_date             { Date.today.ago(2.years) }
    validity_end_date               { nil }

    trait :xml do
      additional_code_type_id       { "F" }
      additional_code               { "397" }
      validity_end_date             { Date.today.ago(1.years) }
    end
  end

  factory :footnote_association_meursing_heading do
    meursing_table_plan_id          { Forgery(:basic).text(exactly: 2) }
    meursing_heading_number         { Forgery(:basic).number }
    footnote_id                     { Forgery(:basic).text(exactly: 3) }
    footnote_type                   { Forgery(:basic).text(exactly: 2) }
    validity_start_date             { Date.today.ago(2.years) }
    validity_end_date               { nil }

    trait :xml do
      row_column_code               { 0 }
      validity_end_date             { Date.today.ago(1.years) }
    end
  end

  factory :footnote_type do
    footnote_type_id    { Forgery(:basic).text(exactly: 2) }
    validity_start_date { Date.today.ago(2.years) }
    validity_end_date   { nil }

    trait :xml do
      application_code  { 4 }
      validity_end_date { Date.today.ago(1.years) }
    end
  end

  factory :footnote_type_description do
    footnote_type_id                { Forgery(:basic).text(exactly: 2) }
    description                     { Forgery(:lorem_ipsum).sentence }

    trait :xml do
      language_id { "EN" }
    end
  end
end
