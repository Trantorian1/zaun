use appchain_utils::invoke_contract;
use appchain_utils::LocalWalletSignerMiddleware;
use color_eyre::Result;
use starknet_core::types::U256;
use starknet_core::types::{Felt, InvokeTransactionResult};

pub struct CoreContract {
    signer: LocalWalletSignerMiddleware,
    address: Felt,
}

impl CoreContract {
    pub fn new(address: Felt, signer: LocalWalletSignerMiddleware) -> Self {
        Self { signer, address }
    }

    pub async fn update_state(
        &self,
        snos_output: Vec<Felt>,
        program_output: Vec<Felt>,
        onchain_data_hash: Felt,
        onchain_data_size: U256,
    ) -> Result<InvokeTransactionResult> {
        let mut calldata = Vec::with_capacity(snos_output.len() + program_output.len() + 5);
        calldata.push(Felt::from(snos_output.len()));
        calldata.extend(snos_output);
        calldata.push(Felt::from(program_output.len()));
        calldata.extend(program_output);
        calldata.push(onchain_data_hash);
        calldata.push(onchain_data_size.low().into());
        calldata.push(onchain_data_size.high().into());

        invoke_contract(&self.signer, self.address, "update_state", calldata).await
    }
}
