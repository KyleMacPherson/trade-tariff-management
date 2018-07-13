//= require ./duty-expression-formatter
//= require ./measure-condition-formatter
//= require ./url-parser
//= require ./db

$(document).ready(function() {
  var form = document.querySelector(".bulk-edit-measures");

  if (!form) {
    return;
  }

  var app = new Vue({
    el: form,
    data: function() {
      var data = {
        selectedMeasures: [],
        showTooltips: true,
        columns: [
          {enabled: true, title: "ID", field: "measure_sid", sortable: true, type: "number", changeProp: "measure_sid" },
          {enabled: true, title: "Regulation", field: "regulation", sortable: true, type: "string", changeProp: "regulation" },
          {enabled: true, title: "Type", field: "measure_type_id", sortable: true, type: "string", changeProp: "measure_type" },
          {enabled: true, title: "Valid from", field: "validity_start_date", sortable: true, type: "date", changeProp: "validity_start_date" },
          {enabled: true, title: "Valid to", field: "validity_end_date", sortable: true, type: "date", changeProp: "validity_end_date" },
          {enabled: true, title: "Commodity code", field: "goods_nomenclature", sortable: true, type: "string", changeProp: "goods_nomenclature" },
          {enabled: true, title: "Additional code", field: "additional_code", sortable: true, type: "string", changeProp: "additional_code" },
          {enabled: true, title: "Origin", field: "geographical_area", sortable: false, changeProp: "geographical_area" },
          {enabled: true, title: "Origin exclusions", field: "excluded_geographical_areas", sortable: false, changeProp: "excluded_geographical_areas" },
          {enabled: true, title: "Duties", field: "duties", sortable: false, changeProp: "duties" },
          {enabled: true, title: "Conditions", field: "conditions", sortable: false, changeProp: "conditions" },
          {enabled: true, title: "Footnotes", field: "footnotes", sortable: false, changeProp: "footnotes" },
          {enabled: true, title: "Last updated", field: "last_updated", sortable: true, type: "date", changeProp: "last_updated" },
          {enabled: true, title: "Status", field: "status", sortable: true, type: "string", changeProp: "status" }
        ],
        actions: [
          { value: 'toggle_unselected', label: 'Hide/Show unselected items' },
          { value: 'change_regulation', label: 'Change generating regulation' },
          { value: 'change_validity_period', label: 'Change validity period...' },
          { value: 'change_origin', label: 'Change origin...' },
          { value: 'change_commodity_codes', label: 'Change commodity codes...' },
          { value: 'change_additional_code', label: 'Change additional code...' },
          { value: 'change_duties', label: 'Change duties...' },
          { value: 'change_conditions', label: 'Change conditions...' },
          { value: 'change_footnotes', label: 'Change footnotes...' },
          { value: 'remove_from_group', label: 'Remove from group...' },
          { value: 'delete', label: 'Delete measures' },
        ],
        measures: [],
        changingDuties: false,
        changingConditions: false,
        deleting: false,
        removingFromGroup: false,
        changingFootnotes: false,
        changingAdditionalCode: false,
        changingCommodityCodes: false,
        changingOrigin: false,
        changingRegulation: false,
        changingValidityPeriod: false,
        isLoading: true,
        selectedAllMeasures: true,
        pagination: {
          total_count: window.__pagination_metadata.total_count,
          page: window.__pagination_metadata.page,
          per_page: window.__pagination_metadata.per_page,
          pages: Math.ceil(window.__pagination_metadata.total_count / window.__pagination_metadata.per_page)
        }
      };

      var query = parseQueryString(window.location.search.substring(1));

      data.search_code = query.search_code;

      return data;
    },
    mounted: function() {
      var self = this;

      DB.getMeasuresBulk(self.search_code, function(row) {
        if (row === undefined) {
          self.loadMeasures(1, self.loadNextPage.bind(self));
        } else {
          self.measures = row.payload.map(function(measure) {
            if (!measure.changes) {
              measure.changes = [];
            }

            return measure;
          });

          self.isLoading = false;
        }
      });
    },
    computed: {
      noSelectedMeasures: function() {
        return this.selectedMeasures.length === 0;
      },
      visibleMeasures: function() {
        return this.measuresForTable.filter(function (measure) {
          return measure.visible;
        });
      },
      selectedMeasureObjects: function() {
        var selectedSids = this.selectedMeasures;

        return this.measures.filter(function(measure) {
          return selectedSids.indexOf(measure.measure_sid) > -1;
        });
      },
      measuresForTable: function() {
        return this.measures.map(function(measure) {
          var formatted_exclusions = measure.excluded_geographical_areas.map(function (ega) {
            return ega.geographical_area_id;
          }).join(", ") || "-";

          var formatted_components = measure.measure_components.map(function (mc) {
            return DutyExpressionFormatter.format({
              duty_expression_id: mc.duty_expression.duty_expression_id,
              duty_expression_description: mc.duty_expression.description,
              duty_expression_abbreviation: mc.duty_expression.abbreviation,
              duty_amount: mc.duty_amount,
              monetary_unit: mc.monetary_unit,
              monetary_unit_abbreviation: mc.monetary_unit ? mc.monetary_unit.abbreviation : null,
              measurement_unit: mc.measurement_unit,
              measurement_unit_qualifier: mc.measurement_unit_qualifier
            });
          }).join(" ");

          var formatted_conditions = measure.measure_conditions.map(function(mc) {
            return MeasureConditionFormatter.format(mc);
          }).join(", ") || "-";

          var formatted_footnotes = measure.footnotes.map(function (ft) {
            return ft.footnote_type_id + " - " + ft.footnote_id;
          }).join(", ") || "-";

          var origin = "-";

          if (measure.geographical_area) {
            if (measure.geographical_area.is_country) {
              origin = measure.geographical_area.geographical_area_id;
            } else {
              origin = measure.geographical_area.description;
            }
          }

          return {
            measure_sid: measure.measure_sid,
            regulation: measure.regulation.formatted_id,
            measure_type_id: measure.measure_type.measure_type_id,
            goods_nomenclature: measure.goods_nomenclature ? measure.goods_nomenclature.goods_nomenclature_item_id : "-",
            additional_code: measure.additional_code || "-",
            geographical_area: origin,
            excluded_geographical_areas: formatted_exclusions,
            duties: formatted_components,
            conditions: formatted_conditions,
            footnotes: formatted_footnotes,
            last_updated: measure.operation_date,
            status: measure.status,
            visible: measure.visible,
            validity_start_date: measure.validity_start_date,
            validity_end_date: measure.validity_end_date || "&ndash;",
            changes: measure.changes
          }
        });
      }
    },
    methods: {
      addOriginExclusion: function() {
        this.origin_exclusions.push({ value: '' });
      },
      onItemSelected: function(sid) {
        this.selectedMeasures.push(sid);
      },
      onItemDeselected: function(sid) {
        var index = this.selectedMeasures.indexOf(sid);

        if (index === -1) {
          return;
        }

        this.selectedMeasures.splice(index, 1);
      },
      toggleUnselected: function() {
        var selected = this.selectedMeasures;

        this.measures.forEach(function(measure) {
          if (selected.indexOf(measure.measure_sid) === -1) {
            measure.visible = !measure.visible;
          }
        });
      },

      triggerAction: function(val) {

        switch(val) {
          case 'toggle_unselected':
            this.toggleUnselected();
            break;
          case 'change_regulation':
            this.changingRegulation = true;
            break;
          case 'change_validity_period':
            this.changingValidityPeriod = true;
            break;
          case 'change_origin':
            this.changingOrigin = true;
            break;
          case 'change_commodity_codes':
            this.changingCommodityCodes = true;
            break;
          case 'change_additional_code':
            this.changingAdditionalCode = true;
            break;
          case 'change_duties':
            this.changingDuties = true;
            break;
          case 'change_conditions':
            this.changingConditions = true;
            break;
          case 'change_footnotes':
            this.changingFootnotes = true;
            break;
          case 'remove_from_group':
            this.removingFromGroup = true;
            break;
          case 'delete':
            this.deleting = true;
            break;
        }
      },
      closeAllPopups: function() {
        this.changingDuties = false;
        this.changingConditions = false;
        this.deleting = false;
        this.removingFromGroup = false;
        this.changingFootnotes = false;
        this.changingAdditionalCode = false;
        this.changingCommodityCodes = false;
        this.changingOrigin = false;
        this.changingRegulation = false;
        this.changingValidityPeriod = false;
      },
      loadMeasures: function(page, callback) {
        var self = this;

        var url = window.location.href + "&page=" + page;

        $.get(url, function(data) {
          self.measures = self.measures.concat(data.measures.map(function(measure) {
            measure.visible = true;

            if (!measure.changes) {
              measure.changes = [];
            }

            return measure;
          }));

          self.pagination.page = parseInt(data.current_page, 10);
          self.pagination.pages = parseInt(data.total_pages, 10);

          callback();
        });
      },
      loadNextPage: function() {
        var self = this;

        if (this.pagination.page === this.pagination.pages) {
          this.isLoading = false;

          DB.insertOrReplaceBulk(self.search_code, self.measures);

          return;
        }

        this.loadMeasures(this.pagination.page + 1, this.loadNextPage.bind(this));
      },
      saveForCrossCheck: function() {
        window.__save_bulk_edit_of_measures_mode = "save_group_for_cross_check";
        this.startSavingProcess();
      },
      saveProgress: function () {
        window.__save_bulk_edit_of_measures_mode = "save_progress";
        this.startSavingProcess();
      },
      startSavingProcess: function() {
        BulkEditOfMeasuresSaveActions.toogleSaveSpinner();

        window.__sb_measures_collection =  this.measures;
        window.__sb_total_count = window.__sb_measures_collection.length;
        window.__sb_per_page = window.__pagination_metadata["per_page"];
        window.__sb_total_pages = Math.ceil(window.__sb_total_count / window.__sb_per_page);
        window.__sb_current_batch = 1;

        BulkEditOfMeasuresSaveActions.sendSaveRequest();
      },
      measuresUpdated: function() {
        DB.insertOrReplaceBulk(this.search_code, this.measures);
      },
      selectAllHasChanged: function(value) {
        this.selectedAllMeasures = value;
      },
      measuresRemoved: function(removedMeasures) {
        var self = this;
        removedMeasures.forEach(function(removedMeasure) {
          var index = self.measures.indexOf(removedMeasure);
          self.measures.splice(index, 1);
        });
        this.measuresUpdated();
      },
      allMeasuresRemoved: function() {
        DB.destroyMeasuresBulk(this.search_code);
      }
    }
  });
});
