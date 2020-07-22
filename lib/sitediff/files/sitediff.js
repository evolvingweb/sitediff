/**
 * @file
 * SiteDiff report behaviors.
 */

'use strict';

/* global $ */
/**
 * SiteDiff namespace.
 */
var SiteDiff = SiteDiff || {};

/**
 * SiteDiff global map of diffs.
 */
SiteDiff.diffs = SiteDiff.diffs || {};

SiteDiff.currentDiff = -1;

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
        break;
    }
};

/**
 * Initializes report filters and overlay.
 */
SiteDiff.initFilterForm = function () {
    SiteDiff.initDiffArray();
    SiteDiff.initStatusFilter();
    SiteDiff.initSearchFilter();
    SiteDiff.initOverlay();
    SiteDiff.initClickHandlers();
};

/**
 * Initialize global diff array
 *
 */
SiteDiff.initDiffArray = function() {
    SiteDiff.diffs = $('.button-diff').map(function (i, element) {
        var $el = $(element);
        $el.data('diffindex', i);
        return {
            diff: $el.attr('href'),
            element: $el,
            index: i,
            path: $el.parents('.description').find('.path').text()
        };
    });
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
 * Set up the diff overlay to be displayed.
 */
SiteDiff.initOverlay = function () {
    if (SiteDiff.diffs.length <= 0) return;

    // add overlay
    $('body').append($(
        '<div class="overlay" style="display: none;"><div class="overlay__inner"><header>' +
        '<div class="path"></div>' +
        '<div class="prev"><a href="#">< Prev</a></div>' +
        '<div class="next"><a href="#">Next ></a></div>' +
        '<div class="exit"><a href="#">Exit</a></div>' +
        '</header><article></article></div></div>'));
    // add header click handlers
    $('.overlay header .exit').click(function (event) {
        event.preventDefault();
        SiteDiff.destroyOverlay();
    });
    $('.overlay header .prev').click(function (event) {
        event.preventDefault();
        SiteDiff.prevDiff();
    });
    $('.overlay header .next').click(function (event) {
        event.preventDefault();
        SiteDiff.nextDiff();
    });

};

/**
 * Set up click handlers for all diff buttons
 */
SiteDiff.initClickHandlers = function () {
    SiteDiff.diffs.each( function (i, diff) {
        diff.element.click({index: i}, function (event) {
            event.preventDefault();
            SiteDiff.openOverlay(event.data.index);
        });
    });
};

/**
 * Open overlay for the diff identified by the `index`.
 *
 * @param integer index
 *      The index of the diff to be viewed.
 */
SiteDiff.openOverlay = function (index) {
    var diff = SiteDiff.diffs[index];
    SiteDiff.currentDiff = index;
    // create header
    $('.overlay header .path').text(diff.path);
    SiteDiff.showDiff();
    $('.overlay').fadeIn(300);
};

/**
 * Create the iframe to display the current diff.
 */
SiteDiff.showDiff = function () {
    var diff = SiteDiff.diffs[SiteDiff.currentDiff];
    var iframe = '<iframe src="' + diff.diff + '"></iframe>';
    SiteDiff.setPrevNext();
    $('.overlay article').html(iframe);
};

/**
 * Hide the overlay and clean up.
 */
SiteDiff.destroyOverlay = function () {
    $('.overlay article').empty();
    $('.overlay').fadeOut(300, SiteDiff.scrollToButton);
};

/**
 * Display the previous diff.
 */
SiteDiff.prevDiff = function () {
    if (SiteDiff.currentDiff > 0) {
        SiteDiff.currentDiff--;
        SiteDiff.showDiff();
    }
};

/**
 * Display the next diff.
 */
SiteDiff.nextDiff = function () {
    if (SiteDiff.currentDiff < SiteDiff.diffs.length - 1) {
        SiteDiff.currentDiff++;
        SiteDiff.showDiff();
    }
};

/**
 * Enable or disable prev and next buttons based on current diff.
 */
SiteDiff.setPrevNext = function () {
    if (SiteDiff.currentDiff <= 0) {
        // set prev disabled
        $('.overlay header .prev').addClass('disabled');
    }
    else {
        $('.overlay header .prev.disabled').removeClass('disabled');
    }
    if (SiteDiff.currentDiff >= SiteDiff.diffs.length - 1) {
        // set next disabled
        $('.overlay header .next').addClass('disabled');
    }
    else {
        $('.overlay header .next.disabled').removeClass('disabled');
    }
};

/**
 * Scroll to the button associated with the current diff.
 */
SiteDiff.scrollToButton = function () {
    var $diffButton = SiteDiff.diffs[SiteDiff.currentDiff].element;
    if (! SiteDiff.isElementVisible($diffButton)) {
        SiteDiff.scrollToElement($diffButton);
    }
};

/**
 * Check if an element is at least partly visible.
 * @param element
 */
SiteDiff.isElementVisible = function (element) {
    var topVisible = $(window).scrollTop();
    var bottomVisible = topVisible + $(window).height();
    var elemTop = $(element).offset().top;
    var elemBottom = elemTop + $(element).height();
    return ((elemBottom <= bottomVisible) && (elemTop >= topVisible));
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
