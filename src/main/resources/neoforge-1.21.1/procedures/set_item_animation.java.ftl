<#include "mcitems.ftl">
if (!world.isClientSide()) {
	final int _animState = ${field$operation}${opt.toInt(input$value)};
	final long _animTime = (world instanceof Level _lvl${cbi}) ? _lvl${cbi}.getGameTime() : 0;
	CustomData.update(DataComponents.CUSTOM_DATA, ${mappedMCItemToItemStackCode(input$item, 1)}, tag -> {
		tag.putInt("animState", _animState);
		tag.putLong("animTime", _animTime);
	});
}