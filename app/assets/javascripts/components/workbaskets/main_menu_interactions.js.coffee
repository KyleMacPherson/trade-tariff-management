window.MainMenuInteractions =

  init: () ->
    MainMenuInteractions.deleteWorkbasketConfirmationPopupInit();
    MainMenuInteractions.withdrawWorkbasketConfirmationPopupInit();
    MainMenuInteractions.handleConfirmationLink();
    MainMenuInteractions.closeConfirmationPopup();

  deleteWorkbasketConfirmationPopupInit: () ->
    $(document).on 'click', '.js-main-menu-show-delete-confirmation-link', ->
      target_url = $(this).data("target-url")
      confirm_link = $("#main-menu-delete_confirmation_popup .js-main-menu-confirm-action")
      confirm_link.attr('href', target_url)
      confirm_link.attr('data-method', 'delete')

      MainMenuInteractions.setSpinnerText("main-menu-delete_confirmation_popup", "Deletion")
      MainMenuInteractions.openModal('main-menu-delete_confirmation_popup')

      return false

  withdrawWorkbasketConfirmationPopupInit: () ->
    $(document).on 'click', '.js-main-menu-show-withdraw-confirmation-link', ->
      target_url = $(this).data("target-url")
      confirm_link = $("#main-menu-withdraw_confirmation_popup .js-main-menu-confirm-action")
      confirm_link.attr('href', target_url)

      MainMenuInteractions.setSpinnerText("main-menu-delete_confirmation_popup", "Processing")
      MainMenuInteractions.openModal('main-menu-withdraw_confirmation_popup')

      return false

  handleConfirmationLink: () ->
    $(document).on 'click', '.js-main-menu-confirm-action', ->
      $(this).addClass('hidden')
      spinner = $(".js-workbasket-base-save-progress-spinner")
      spinner.removeClass('hidden')

      return false

  closeConfirmationPopup: () ->
    $(document).on 'click', '.js-main-menu-close-confirmation-popup', ->
      popup_id = $(this).data('popup-id')
      MainMenuInteractions.closePopup(popup_id)

      return false

  openModal: (popup_id) ->
    MicroModal.show(popup_id)
    return false

  closePopup: (popup_id) ->
    $.each $(".js-main-menu-confirm-action"), (index, element) ->
      confirm_link = $(element)
      confirm_link.attr('href', '')
      confirm_link.removeAttr('data-method')

    MicroModal.close(popup_id)
    return false

  setSpinnerText: (popup_id, message) ->
    $("#" + popup_id + " .saving_message").text(message)

$ ->
  MainMenuInteractions.init();
