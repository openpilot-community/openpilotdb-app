# == Schema Information
#
# Table name: hardware_types
#
#  id          :bigint(8)        not null, primary key
#  name        :string
#  description :text
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#

class HardwareType < ApplicationRecord
  extend FriendlyId
  friendly_id :name, use: :slugged
  has_many :hardware_items

  def description_markup
    if self.description.present?
      description_renderer = Redcarpet::Markdown.new(Redcarpet::Render::HTML, autolink: true, tables: true)
      description_renderer.render(self.description)
    end
  end
end
