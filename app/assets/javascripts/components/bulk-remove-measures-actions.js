window.BulkRemoveMeasuresActions = {
  getWorkbasketId: function(){
    return window.__workbasket_id;
  },
  removeMeasures: function(measures){
    var measuresSids = measures.map(function(measure){
      return measure.measure_sid;
    });

    return $.ajax({
      url: "/measures/bulks/" + this.getWorkbasketId() + "/bulk_items/remove_items.json",
      data: JSON.stringify(measuresSids),
      type: "POST",
      processData: false,
      contentType: "application/json"
    });
  },
  removeAllMeasuresInWorkbasket: function(){
    return $.ajax({
      url: "/measures/bulks/" + this.getWorkbasketId(),
      type: "DELETE",
      processData: false,
      contentType: "application/json"
    });
  }
};