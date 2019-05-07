/**
 * @file
 * SiteDiff report behaviors.
 */

/**
 * SiteDiff namespace.
 */
var SiteDiff = SiteDiff || {};

/**
 * Scrolls the document to the said position.
 *
 * @param options
 *   Object specifying various options.
 *
 *   x: X position.
 *   y: Y position.
 *   animate: Whether to animate.
 *   callback: A function to call after scrolling.
 */
SiteDiff.scrollToPosition = function (options) {
    // Compute vertical and horizontal adjustments, if any.
    // Example: Fixed elements, etc.
    var xFix = 0;
    var yFix = 0 - 100;

    // Determine final x and y offsets.
    var x = parseInt(options.x) + xFix;
    x = Math.max(x, 0);
    var y = parseInt(options.y) + yFix;
    y = Math.max(y, 0);

    // Perform the scroll with or without animation.
    window.scrollTo(x, y);

    // Trigger a callback, if any.
    if (options.callback) {
        options.callback();
    }
};

/**
 * Scrolls to a DOM element on the page.
 *
 * @param el
 *   The DOM element.
 *
 * @param options
 *   Object specifying various options.
 *
 *   "callback" to trigger after scrolling.
 */
SiteDiff.scrollToElement = function (el, options) {
    options = options || {};
    var callback = options.callback || function () {};

    // See if the element exists.
    var $el = $(el).first();
    if ($el.length == 1) {
        // Inject callback to focus on the element we scroll to.
        options.x = 0;
        options.y = $el.offset().top;
        options.callback = function () {
            $el.focus();
            callback.call(el);
        };
        SiteDiff.scrollToPosition(options);
    }
};

/**
 * Initialize behaviors.
 */
SiteDiff.init = function () {
    // On the overview page.
    switch ($(document.body).data('page')) {
        case 'overview':
            SiteDiff.initFilterForm();
            break;

        case 'diff':
            SiteDiff.jumpToFirstDiff();
            // TODO: Create a prev-next mechanism.
            break;
    }
};

/**
 * Initializes report filters.
 */
SiteDiff.initFilterForm = function () {
    SiteDiff.initStatusFilter();
    SiteDiff.initSearchFilter();
};

/**
 * Initializes the "status" filter.
 */
SiteDiff.initStatusFilter = function () {
    $('.form-item--status input')
        .on('change', function () {
            // Get a list of applied filters.
            var appliedFilters = $('.form-item--status input:checked')
               .map(function () {
                   return this.getAttribute('value');
                   // applied.push(this.getAttribute('value'));
                   // console.log(applied);
               });
            // Show only matching results, hide the rest.
            $('#sitediff-report')
                .find('.sitediff-result')
                .each(function () {
                    var $row = $(this);
                    var status = $row.data('status');
                    if (
                        // Row matches applied filters.
                        $.inArray(status, appliedFilters) > -1 ||
                        // No filters are applied.
                        appliedFilters.length === 0
                    ) {
                        $row.removeAttr('hidden');
                    }
                    else {
                        $row.attr('hidden', 'hidden');
                    }
                });
        });
};

/**
 * Initializes the "search" filter.
 */
SiteDiff.initSearchFilter = function () {
    $('#input-search')
        .on('change keyup', function () {
            var keyword = $(this).val().toLowerCase();

            // Filter the records.
            // TODO: Trigger one event per 250ms.
            $('#sitediff-report')
                .find('.sitediff-result')
                .each(function () {
                    var $row = $(this);
                    var path = $row.find('.path').text();

                    // If keyword matches, keep the row visible.
                    if (path.toLowerCase().indexOf(keyword) > -1) {
                        $row.attr('hidden', null);
                    }
                    else {
                        $row.attr('hidden', 'hidden');
                    }
                });
        });
};

/**
 * Jumps to the first diff on the page.
 */
SiteDiff.jumpToFirstDiff = function () {
    // Get the first diff hunk.
    var $diff = $('#diff-container')
        .find('.del, .ins')
        .first();
    if ($diff.length === 0) {
        return;
    }

    // Scroll the window to it!
    setTimeout(function () {
        SiteDiff.scrollToElement($diff[0]);
    }, 250);
};

$(document).ready(SiteDiff.init);
