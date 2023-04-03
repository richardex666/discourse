# frozen_string_literal: true

RSpec.describe "Channel - Info - About page", type: :system, js: true do
  fab!(:channel_1) { Fabricate(:category_channel) }

  let(:chat_page) { PageObjects::Pages::Chat.new }

  before { chat_system_bootstrap }

  context "as regular user" do
    fab!(:current_user) { Fabricate(:user) }

    before { sign_in(current_user) }

    it "shows channel info" do
      chat_page.visit_channel_about(channel_1)

      expect(page.find(".category-name")).to have_content(channel_1.chatable.name)
      expect(page.find(".channel-info-about-view__name")).to have_content(channel_1.title)
      expect(page.find(".channel-info-about-view__slug")).to have_content(channel_1.slug)
    end

    it "escapes channel title" do
      channel_1.update!(name: "<script>alert('hello')</script>")
      chat_page.visit_channel_about(channel_1)

      expect(page.find(".channel-info-about-view__name")["innerHTML"].strip).to eq(
        "&lt;script&gt;alert('hello')&lt;/script&gt;",
      )
      expect(page.find(".chat-channel-title__name")["innerHTML"].strip).to eq(
        "&lt;script&gt;alert('hello')&lt;/script&gt;",
      )
    end

    it "can’t edit name or slug" do
      chat_page.visit_channel_about(channel_1)

      expect(page).to have_no_selector(".edit-name-slug-btn")
    end

    it "can’t edit description" do
      chat_page.visit_channel_about(channel_1)

      expect(page).to have_no_selector(".edit-description-btn")
    end

    context "as a member" do
      before { channel_1.add(current_user) }

      it "can leave channel" do
        chat_page.visit_channel_about(channel_1)
        membership = channel_1.membership_for(current_user)

        expect {
          click_button(I18n.t("js.chat.channel_settings.leave_channel"))
          expect(page).to have_content(I18n.t("js.chat.channel_settings.join_channel"))
        }.to change { membership.reload.following }.from(true).to(false)
      end
    end

    context "as not a member" do
      it "can join channel" do
        chat_page.visit_channel_about(channel_1)

        expect {
          click_button(I18n.t("js.chat.channel_settings.join_channel"))
          expect(page).to have_content(I18n.t("js.chat.channel_settings.leave_channel"))
        }.to change {
          Chat::UserChatChannelMembership.where(user_id: current_user.id, following: true).count
        }.by(1)
      end
    end
  end

  context "as admin" do
    fab!(:current_user) { Fabricate(:admin) }

    before { sign_in(current_user) }

    it "can edit name" do
      chat_page.visit_channel_about(channel_1)
      find(".edit-name-slug-btn").click

      expect(find(".chat-channel-edit-name-slug-modal__name-input").value).to eq(channel_1.title)

      name = "A new name"
      find(".chat-channel-edit-name-slug-modal__name-input").fill_in(with: name)
      find(".create").click

      expect(page).to have_content(name)
    end

    it "can edit description" do
      chat_page.visit_channel_about(channel_1)
      find(".edit-description-btn").click

      expect(page).to have_selector(
        ".chat-channel-edit-description-modal__description-input",
        text: channel_1.description,
      )

      description = "A new description"
      find(".chat-channel-edit-description-modal__description-input").fill_in(with: description)
      find(".create").click

      expect(page).to have_content(description)
    end

    it "can edit slug" do
      chat_page.visit_channel_about(channel_1)
      find(".edit-name-slug-btn").click

      expect(find(".chat-channel-edit-name-slug-modal__slug-input").value).to eq(channel_1.slug)

      slug = "gonzo-slug"
      find(".chat-channel-edit-name-slug-modal__slug-input").fill_in(with: slug)
      find(".create").click

      expect(page).to have_content(slug)
    end

    it "can clear the slug to use the autogenerated version based on the name" do
      channel_1.update!(name: "test channel")
      chat_page.visit_channel_about(channel_1)
      find(".edit-name-slug-btn").click

      slug_input = find(".chat-channel-edit-name-slug-modal__slug-input")
      expect(slug_input.value).to eq(channel_1.slug)

      slug_input.fill_in(with: "")
      wait_for_attribute(slug_input, :placeholder, "test-channel")
      find(".create").click

      expect(page).to have_content("test-channel")
    end
  end
end
