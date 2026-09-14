#include <fcntl.h>
#include <string.h>
#include <unistd.h>
#include <android-base/properties.h>

#define _REALLY_INCLUDE_SYS__SYSTEM_PROPERTIES_H_
#include <sys/_system_properties.h>

using std::string;

void property_override(string prop, string value)
{
    auto pi = (prop_info *)__system_property_find(prop.c_str());

    if (pi != nullptr)
        __system_property_update(pi, value.c_str(), value.size());
    else
        __system_property_add(prop.c_str(), prop.size(), value.c_str(), value.size());
}

// Xiaomi stores the sales region as plain text in the dedicated "countrycode"
// partition (values such as "CN", "GLOBAL", "INDIA", "EEA", "RU", "TW").
// The region decides the retail model number of the unit. Report the true
// retail model of the hardware instead of a hardcoded string so that the
// recovery identity always matches the shipped unit.
static string read_countrycode()
{
    char buf[33];
    string region;

    int fd = open("/dev/block/by-name/countrycode", O_RDONLY);
    if (fd < 0)
        return region;

    ssize_t n = read(fd, buf, sizeof(buf) - 1);
    close(fd);
    if (n <= 0)
        return region;

    buf[n] = '\0';
    for (int i = 0; buf[i]; i++) {
        if (buf[i] >= ' ' && buf[i] <= '~')
            region += buf[i];
        else
            break;
    }
    return region;
}

static bool is_china_region(const string &region)
{
    if (region.size() != 2)
        return false;
    return (region[0] == 'C' || region[0] == 'c') &&
           (region[1] == 'N' || region[1] == 'n');
}

void vendor_load_properties()
{
    // Retail models by region:
    //   China  -> 2407FRK8EC (Redmi K70 Ultra, same "rothko" board)
    //   Global -> 2407FPN8EG (Xiaomi 14T Pro)
    // Default to the Global 14T Pro model (this tree's target device, see
    // README.md and PRODUCT_MODEL in twrp_rothko.mk) when the countrycode
    // partition cannot be read.
    string model = "2407FPN8EG";
    if (is_china_region(read_countrycode()))
        model = "2407FRK8EC";

    string prop_partitions[] = {"", "vendor.", "odm."};
    for (const string &prop : prop_partitions)
    {
        property_override(string("ro.product.") + prop + string("brand"), "Xiaomi");
        property_override(string("ro.product.") + prop + string("manufacturer"), "Xiaomi");
        property_override(string("ro.product.") + prop + string("name"), "rothko");
        property_override(string("ro.product.") + prop + string("device"), "rothko");
        property_override(string("ro.product.") + prop + string("model"), model);
        property_override(string("ro.product.") + prop + string("marketname"), "Xiaomi 14T Pro");
        property_override(string("ro.product.") + prop + string("cert"), model);
    }
    property_override("ro.bootimage.build.date.utc", "1756453697");
    property_override("ro.build.date.utc", "1756453697");
}
