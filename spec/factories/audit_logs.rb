FactoryBot.define do
  factory :audit_log do
    auditable_type { "MyString" }
    auditable_id { 1 }
    action { "MyString" }
    audit_data { "MyText" }
    created_at { "2025-06-28 09:10:07" }
  end
end
