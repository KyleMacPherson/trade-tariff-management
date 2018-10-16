$(document).ready(function() {
  var form = document.querySelector(".js-search-certificate-section");

  if (!form) {
    return;
  }

  var app = new Vue({
    el: form,
    data: function() {
      var data = {
        errors: {},
        errorsSummary: "",
        footnote_types_list: window.__footnote_types_list_json
      };

      if (!$.isEmptyObject(window.__search_certificate_settings_json)) {
        data.search = this.parseFootnoteFormPayload(window.__search_certificate_settings_json);
      } else {
        data.search = this.emptyFootnoteForm();
      }

      return data;
    },
    mounted: function() {
      var self = this;

      $(document).on('click', ".js-validate-certificate-search-form", function(e) {
        e.preventDefault();
        e.stopPropagation();

        submit_button = $(this);

        WorkbasketBaseSaveActions.toogleSaveSpinner($(this).attr('name'));

        $.ajax({
          url: window.__validate_search_settings_url,
          type: "GET",
          data: {
            search: self.footnoteFormPayload()
          },
          success: function(response) {
            self.errors = [];
            WorkbasketBaseSaveActions.unlockButtonsAndHideSpinner();

            $(".js-search-certificate-form").submit();
          },
          error: function(response) {
            WorkbasketBaseSaveActions.unlockButtonsAndHideSpinner();

            if (response.status == 500) {
              alert("There was a server error which prevented the search to be performed. Please try again in a few moments.");
              return;
            }

            self.errorsSummary = response.responseJSON.errors.general_summary;
            self.errors = response.responseJSON.errors;
          }
        });

        DatepickerRangeMonkeyPatch.fix();
      });
    },
    computed: {
      hasErrors: function() {
        return Object.keys(this.errors).length > 0;
      }
    },
    methods: {
      parseFootnoteFormPayload: function(payload) {
        return {
          footnote_type_id: payload.footnote_type_id,
          q: payload.q,
          commodity_codes: payload.commodity_codes,
          measure_sids: payload.measure_sids,
          start_date: payload.start_date,
          end_date: payload.end_date
        };
      },
      emptyFootnoteForm: function() {
        return {
          footnote_type_id: null,
          q: null,
          commodity_codes: null,
          measure_sids: null,
          start_date: null,
          end_date: null
        };
      },
      footnoteFormPayload: function() {
        return {
          footnote_type_id: this.search.footnote_type_id,
          q: this.search.q,
          commodity_codes: this.search.commodity_codes,
          measure_sids: this.search.measure_sids,
          start_date: $('input[name=\'search[start_date]\']').val(),
          end_date: $('input[name=\'search[end_date]\']').val()
        };
      }
    }
  });
});
