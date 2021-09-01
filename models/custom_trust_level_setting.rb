# frozen_string_literal: true

require_dependency 'enum_site_setting'

class CustomTrustLevelSetting < EnumSiteSetting

  def self.valid_value?(val)
    val.to_i.to_s == val.to_s &&
    valid_values.any? { |v| v == val.to_i }
  end

  def self.values
    # levels = TrustLevel.all
    @values ||= valid_values.map { |x|
      {
        name: translation(x),
        value: x
      }
    }

    @values.unshift({ name: "none", value: -1 })
  end

  def self.valid_values
    TrustLevel.valid_range.to_a.unshift(-1)
  end

  def self.translation(value)
    I18n.t(
      "js.trust_levels.detailed_name",
      level: value,
      name: TrustLevel.name(value)
    )
  end

  private_class_method :valid_values
  private_class_method :translation
end
