$(document).ready(function(){
  $("a[href = '/queries']").click(function(){
    $.post("queries", {name: "ass"}, function(json){}, "json");
  });

  $(".sub.btn-success").click(function(){
    var id = this.id.substring(3, this.id.length);
    $.post("approve", { id: id }, function(html){
      if (html == '1') {
        var target = $('#btn' + id);
        target.parent().parent().parent().hide('slow', function(){ target.remove(); });
      }
      else if (html == '0')
        alert("Превышает 10% бюджета!")
      else
        alert("Столько денег не добыть!")
    }, "html");
  });

  $(".sub.btn-danger").click(function(){
    var id = this.id.substring(3, this.id.length);
    $.post("reject", { id: id }, function(html){
      if (html == '1') {
        var target = $('#btn' + id);
        target.parent().parent().parent().hide('slow', function(){ target.remove(); });
      };
    }, "html");
  });
  
  $(".mail.btn-success").click(function(){
    var id = this.id.substring(3, this.id.length);
    $.post("mail", { id: id }, function(html){
        alert(html);
    }, "html");
  });

  $(".test.btn-success").click(function(){
    var id = this.id;
    var selector = "." + id;
    var query = $(selector).text();
    $.post("test", { id: id, query: query }, function(html){
        alert(html);
    }, "html");
  });

  $('.dropdown-toggle').dropdown();
});