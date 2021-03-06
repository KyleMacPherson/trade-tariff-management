$(document).ready(function() {
  var form = document.querySelector(".additional-codes-show-page");

  if (!form) {
    return;
  }

  var app = new Vue({
    el: form,
    data: function() {
      var data = {
        columns: [
          {enabled: true, title: "Type", field: "type_id", sortable: true, type: "string" },
          {enabled: true, title: "Code", field: "additional_code", sortable: true, type: "string" },
          {enabled: true, title: "Description", field: "description", sortable: true, type: "string" },
          {enabled: true, title: "Valid from", field: "validity_start_date", sortable: true, type: "date" },
          {enabled: true, title: "Valid to", field: "validity_end_date", sortable: true, type: "date" },
          {enabled: true, title: "Last updated", field: "last_updated", sortable: true, type: "string" },
          {enabled: true, title: "Status", field: "status", sortable: true, type: "string", changeProp: "status" }
        ],
        raw_codes: window.additional_codes
      };

      return data;
    },
    computed: {
      additional_codes: function() {
        return this.raw_codes.map(function(code) {
          code.last_updated = "-";

          if (code.workbasket) {
            code.last_updated = code.workbasket.created_at + (code.workbasket.user ? " " + code.workbasket.user.name : "");
          }

          return code;
        });
      }
    }
  });
});
