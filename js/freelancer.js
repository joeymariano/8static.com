/*!
 * Start Bootstrap - Freelancer Bootstrap Theme (http://startbootstrap.com)
 * Code licensed under the Apache License v2.0.
 * For details, see http://www.apache.org/licenses/LICENSE-2.0.
 */

// jQuery for page scrolling feature - requires jQuery Easing plugin
$(function() {
    $('.page-scroll a').bind('click', function(event) {
        var $anchor = $(this);
        $('html, body').stop().animate({
            scrollTop: $($anchor.attr('href')).offset().top
        }, 1500, 'easeInOutExpo');
        event.preventDefault();
    });
});

// Floating label headings for the contact form
$(function() {
    $("body").on("input propertychange", ".floating-label-form-group", function(e) {
        $(this).toggleClass("floating-label-form-group-with-value", !! $(e.target).val());
    }).on("focus", ".floating-label-form-group", function() {
        $(this).addClass("floating-label-form-group-with-focus");
    }).on("blur", ".floating-label-form-group", function() {
        $(this).removeClass("floating-label-form-group-with-focus");
    });
});

// Highlight the top nav as scrolling occurs
$('body').scrollspy({
    target: '.navbar-fixed-top'
})

// Closes the Responsive Menu on Menu Item Click
$('.navbar-collapse ul li a').click(function() {
    $('.navbar-toggle:visible').click();
});

// Shuffle artist grid (on page load + on button click)
$(function() {
    function shuffleArtists(animate) {
        var $row = $('.portfolio-flex-row');
        var items = $row.children('.portfolio-flex-item').get();
        for (var i = items.length - 1; i > 0; i--) {
            var j = Math.floor(Math.random() * (i + 1));
            var tmp = items[i]; items[i] = items[j]; items[j] = tmp;
        }
        if (animate) {
            $row.css({
                transition: 'opacity .5s ease, transform .5s ease',
                opacity: 0,
                transform: 'scale(0.96)'
            });
            setTimeout(function() {
                $row.append(items);
                $row.css({
                    opacity: 1,
                    transform: 'scale(1)'
                });
            }, 550);
        } else {
            $row.append(items);
        }
    }
    shuffleArtists(false);
    $(document).on('click', '#shuffle-artists', function() { shuffleArtists(true); });
});
