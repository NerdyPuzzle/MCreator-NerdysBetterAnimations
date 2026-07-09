<#include "mcitems.ftl">
{
	final int _animState = ${field$operation}${opt.toInt(input$value)};
	CustomData.update(DataComponents.CUSTOM_DATA, ${mappedMCItemToItemStackCode(input$item, 1)}, tag -> {
		tag.putInt("oldAnimState", 10000);
		tag.putInt("animState", _animState);
	});
}