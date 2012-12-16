$(document).ready(function(){
  $("a[href = '/queries']").click(function(){
    $.post("queries", {name: "ass"}, function(json){}, "json");
  });

  $(".btn-success").click(function(){
    var id = this.id.substring(3, this.id.length);
    $.post("approve", { id: id }, function(html){
      if (html == '1') {
        var target = $('#btn' + id);
        target.parent().parent().parent().hide('slow', function(){ target.remove(); });
      };
    }, "html");
  });

  $(".btn-danger").click(function(){
    var id = this.id.substring(3, this.id.length);
    $.post("reject", { id: id }, function(html){
      if (html == '1') {
        var target = $('#btn' + id);
        target.parent().parent().parent().hide('slow', function(){ target.remove(); });
      };
    }, "html");
  });
  
  $('.dropdown-toggle').dropdown();
});