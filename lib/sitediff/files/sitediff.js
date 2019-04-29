/**
 * @file
 * SiteDiff report behaviors.
 */

/**
 * SiteDiff namespace.
 */
var SiteDiff = SiteDiff || {};

/**
 * Initialize behaviors.
 */
SiteDiff.init = function () {
    SiteDiff.initFilterForm();
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

$(document).ready(SiteDiff.init);
